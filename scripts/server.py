#!/usr/bin/env python3
"""
server.py - Rap Analyzer FastAPI Server
iOSアプリから YouTube URL を受け取り、Whisper + GPT-4o + Claude で解析して返す

起動方法:
  cd ~/Rap/scripts
  pip install -r requirements.txt
  python server.py

iPhoneのアプリ側でこのMacのIPを設定してください。
"""

import asyncio
import json
import os
import re
import socket
import sys
import tempfile
import subprocess
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
import uvicorn

load_dotenv()

# ─── Clients ───────────────────────────────────────────────────────────────────

def get_openai():
    from openai import OpenAI
    key = os.environ.get("OPENAI_API_KEY", "")
    if not key:
        raise RuntimeError("OPENAI_API_KEY が .env に設定されていません")
    return OpenAI(api_key=key)

def get_anthropic():
    from anthropic import Anthropic
    key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not key:
        return None  # optional
    return Anthropic(api_key=key)

# ─── Cache ─────────────────────────────────────────────────────────────────────

_cache: dict[str, list] = {}
MAX_CACHE = 20

def extract_video_id(url: str) -> str:
    for pattern in [r"youtu\.be/([a-zA-Z0-9_-]{11})", r"v=([a-zA-Z0-9_-]{11})", r"^([a-zA-Z0-9_-]{11})$"]:
        m = re.search(pattern, url)
        if m:
            return m.group(1)
    return url

# ─── Audio download ─────────────────────────────────────────────────────────────

def download_audio(url: str, start: int = 0) -> str:
    tmpdir = tempfile.mkdtemp()
    out_template = os.path.join(tmpdir, "audio.%(ext)s")
    cmd = ["yt-dlp", "-x", "--audio-format", "mp3", "--audio-quality", "0", "-o", out_template]
    if start > 0:
        cmd += ["--postprocessor-args", f"ffmpeg:-ss {start}"]
    cmd.append(url)

    print(f"⬇️  Downloading: {url} (start={start}s)")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"yt-dlp failed: {result.stderr[:300]}")

    mp3 = os.path.join(tmpdir, "audio.mp3")
    if not os.path.exists(mp3):
        files = list(Path(tmpdir).glob("*.mp3"))
        if not files:
            raise FileNotFoundError("MP3 not found after download")
        mp3 = str(files[0])

    size_mb = os.path.getsize(mp3) / (1024 * 1024)
    print(f"✅ Audio: {mp3} ({size_mb:.1f} MB)")
    return mp3

# ─── Whisper transcription ──────────────────────────────────────────────────────

def transcribe(audio_path: str, openai_client) -> list[dict]:
    print("🎙️  Transcribing with Whisper (word-level timestamps)...")
    with open(audio_path, "rb") as f:
        response = openai_client.audio.transcriptions.create(
            model="whisper-1",
            file=f,
            language="ja",
            response_format="verbose_json",
            timestamp_granularities=["word", "segment"],
        )

    # Build word lookup per segment index
    word_map: dict[int, list] = {}
    if hasattr(response, "words") and response.words:
        for word in response.words:
            for i, seg in enumerate(response.segments):
                if float(seg.start) <= float(word.start) < float(seg.end) + 0.5:
                    word_map.setdefault(i, []).append({
                        "word": word.word,
                        "start": round(float(word.start), 3),
                        "end": round(float(word.end), 3),
                    })
                    break

    segments = []
    for i, seg in enumerate(response.segments):
        text = seg.text.strip()
        if not text:
            continue
        words = word_map.get(i, [])
        start = round(float(words[0]["start"]), 2) if words else round(float(seg.start), 2)
        end = round(float(words[-1]["end"]), 2) if words else round(float(seg.end), 2)
        segments.append({"start": start, "end": end, "text": text})

    print(f"✅ {len(segments)} segments transcribed")
    return segments

# ─── GPT-4o + Claude analysis ───────────────────────────────────────────────────

def analyze_batch(segments: list[dict], rapper1: str, rapper2: str, openai_client, anthropic_client=None) -> list[dict]:
    """Analyze all segments in one GPT-4o call, optionally enrich with Claude."""
    batch_size = 50
    results: list[dict] = []

    # Numbered transcript
    numbered = "\n".join([f"[{i+1}] ({s['start']:.1f}s) {s['text']}" for i, s in enumerate(segments)])

    gpt_system = f"""あなたは伝説的なヒップホップライター兼批評家です。
バトル: {rapper1} vs {rapper2}

各ラインについて以下のJSON形式のみで返してください:
{{
  "entries": [
    {{
      "index": 1,
      "explanation": "意味・文脈・ディス対象・隠語（括弧で意味補足）を1〜2文で解説",
      "technique": "踏んでいる韻（具体的な語）・フロウパターン・パンチライン技法を1文で"
    }}
  ]
}}

解説のポイント:
- 韻は「〇〇と△△で□音の母音韻」と具体的に
- パンチラインは表と裏の意味を
- 隠語は（意味）を括弧補足: シャブ（覚醒剤）、チャカ（拳銃）、ムショ（刑務所）等
- ディスは誰への何の攻撃かを明示"""

    # Process in batches
    for batch_start in range(0, len(segments), batch_size):
        batch = segments[batch_start:batch_start + batch_size]
        batch_numbered = "\n".join([f"[{batch_start + i + 1}] ({s['start']:.1f}s) {s['text']}" for i, s in enumerate(batch)])
        print(f"  🔍 GPT-4o: {batch_start + 1}〜{batch_start + len(batch)} / {len(segments)}")

        try:
            resp = openai_client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": gpt_system},
                    {"role": "user", "content": f"以下{len(batch)}件を解析:\n{batch_numbered}"},
                ],
                response_format={"type": "json_object"},
                max_tokens=4000,
                temperature=0.3,
            )
            data = json.loads(resp.choices[0].message.content)
            entries_map = {e["index"]: e for e in data.get("entries", [])}
        except Exception as ex:
            print(f"  ⚠️  GPT-4o batch failed: {ex}")
            entries_map = {}

        for i, seg in enumerate(batch):
            global_i = batch_start + i + 1
            entry_data = entries_map.get(global_i, {})
            results.append({
                "start": seg["start"],
                "end": seg["end"],
                "lyric": seg["text"],
                "explanation": entry_data.get("explanation", ""),
                "technique": entry_data.get("technique", ""),
            })

    # Optional: Claude enrichment for top 20 segments (adds cultural depth)
    if anthropic_client and results:
        print("  🤖 Claude: enriching cultural context...")
        try:
            sample = results[:20]
            lines = "\n".join([f"[{i+1}] {e['lyric']}" for i, e in enumerate(sample)])
            msg = anthropic_client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=2000,
                messages=[{
                    "role": "user",
                    "content": f"バトル「{rapper1} vs {rapper2}」の以下のラインについて、文化的背景・サンプリング元・バトル史上の意義を各1文で補足してください（JSON: {{\"entries\": [{{\"index\":1, \"context\":\"...\"}}]}}）:\n{lines}"
                }]
            )
            claude_data = json.loads(msg.content[0].text)
            context_map = {e["index"]: e.get("context", "") for e in claude_data.get("entries", [])}
            for i, entry in enumerate(results[:20]):
                if ctx := context_map.get(i + 1):
                    entry["explanation"] = entry["explanation"] + f" / {ctx}"
        except Exception as ex:
            print(f"  ⚠️  Claude enrichment skipped: {ex}")

    return results

# ─── FastAPI app ────────────────────────────────────────────────────────────────

app = FastAPI(title="Rap Analyzer", version="1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

class AnalyzeRequest(BaseModel):
    url: str
    rapper1: str = "MC1"
    rapper2: str = "MC2"
    start: int = 0

@app.get("/health")
def health():
    return {"status": "ok", "version": "1.0", "cache": len(_cache)}

@app.get("/search")
async def search(q: str, limit: int = 20):
    """YouTube search via yt-dlp — no API key needed."""
    if not q.strip():
        return []
    results = await asyncio.to_thread(_search_youtube, q.strip(), limit)
    return results

def _search_youtube(query: str, limit: int) -> list:
    cmd = [
        "yt-dlp",
        f"ytsearch{limit}:{query}",
        "--dump-json",
        "--flat-playlist",
        "--no-download",
        "--no-warnings",
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired:
        return []

    videos = []
    for line in result.stdout.strip().split("\n"):
        if not line.strip():
            continue
        try:
            data = json.loads(line)
            vid_id = data.get("id", "")
            if not vid_id:
                continue
            duration_sec = data.get("duration")
            duration_str = ""
            if isinstance(duration_sec, (int, float)) and duration_sec > 0:
                m, s = divmod(int(duration_sec), 60)
                h, m = divmod(m, 60)
                duration_str = f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"
            videos.append({
                "id": vid_id,
                "title": data.get("title", ""),
                "channelTitle": data.get("uploader") or data.get("channel") or "",
                "thumbnailURL": f"https://img.youtube.com/vi/{vid_id}/mqdefault.jpg",
                "thumbnailHighURL": f"https://img.youtube.com/vi/{vid_id}/hqdefault.jpg",
                "description": data.get("description", ""),
                "publishedAt": str(data.get("upload_date", "")),
                "duration": duration_str,
            })
        except Exception:
            continue
    return videos

@app.post("/analyze")
async def analyze(req: AnalyzeRequest):
    video_id = extract_video_id(req.url)
    cache_key = f"{video_id}_{req.start}"

    if cache_key in _cache:
        print(f"✅ Cache hit: {video_id}")
        return _cache[cache_key]

    try:
        entries = await asyncio.to_thread(_process, req)
    except Exception as e:
        print(f"❌ Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

    # Manage cache size
    if len(_cache) >= MAX_CACHE:
        oldest = next(iter(_cache))
        del _cache[oldest]
    _cache[cache_key] = entries

    return entries

def _process(req: AnalyzeRequest) -> list[dict]:
    openai_client = get_openai()
    anthropic_client = get_anthropic()
    audio_path = download_audio(req.url, req.start)
    segments = transcribe(audio_path, openai_client)
    if not segments:
        raise ValueError("文字起こし結果が空です")
    return analyze_batch(segments, req.rapper1, req.rapper2, openai_client, anthropic_client)

# ─── Main ───────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8765))

    # Detect local IP
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except Exception:
        local_ip = socket.gethostbyname(socket.gethostname())

    print("\n" + "="*55)
    print("  🎤  Rap Analyzer Server")
    print("="*55)
    print(f"  Local:    http://localhost:{port}")
    print(f"  Network:  http://{local_ip}:{port}  ← iPhoneに設定")
    print(f"  Health:   http://{local_ip}:{port}/health")
    print("="*55)
    print("  ✅ APIキーチェック:")
    print(f"     OPENAI_API_KEY:    {'✓' if os.environ.get('OPENAI_API_KEY') else '✗ 未設定'}")
    print(f"     ANTHROPIC_API_KEY: {'✓' if os.environ.get('ANTHROPIC_API_KEY') else '△ 任意'}")
    print("="*55)
    print("  iOSアプリ → 解析 > リリック同期 > ⚙️ サーバーURL")
    print(f"  → http://{local_ip}:{port} を入力してください")
    print("="*55 + "\n")

    uvicorn.run(app, host="0.0.0.0", port=port, log_level="warning")
