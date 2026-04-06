#!/usr/bin/env python3
"""
analyze_battle.py - YouTube MCバトル動画 → Whisper API → GPT-4o → JSON

Usage:
  python analyze_battle.py URL output.json --rapper1 NAME1 --rapper2 NAME2 [--start SECONDS]

Example:
  python analyze_battle.py 'https://youtu.be/3D6KUgNDn40' battle.json \
      --rapper1 'T-Pablow' --rapper2 'R-指定' --start 30

Output format:
  [{"start": float, "end": float, "lyric": str, "explanation": str}, ...]
"""

import argparse
import json
import os
import sys
import tempfile
import subprocess
from pathlib import Path
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()


def get_client() -> OpenAI:
    key = os.environ.get("OPENAI_API_KEY", "")
    if not key:
        print("❌ OPENAI_API_KEY が設定されていません。")
        print("   scripts/.env ファイルに OPENAI_API_KEY=sk-... を追加してください。")
        sys.exit(1)
    return OpenAI(api_key=key)


def download_audio(url: str, start: int = 0) -> str:
    """yt-dlp で YouTube から音声をダウンロードして MP3 パスを返す。"""
    tmpdir = tempfile.mkdtemp()
    output_template = os.path.join(tmpdir, "audio.%(ext)s")

    cmd = [
        "yt-dlp",
        "-x",
        "--audio-format", "mp3",
        "--audio-quality", "0",
        "-o", output_template,
    ]

    if start > 0:
        cmd += ["--postprocessor-args", f"ffmpeg:-ss {start}"]

    cmd.append(url)

    print(f"⬇️  Downloading audio from {url} (start={start}s)...")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stderr)
        raise RuntimeError(f"yt-dlp failed:\n{result.stderr}")

    mp3 = os.path.join(tmpdir, "audio.mp3")
    if not os.path.exists(mp3):
        files = list(Path(tmpdir).glob("*.mp3"))
        if not files:
            raise FileNotFoundError(f"MP3 not found in {tmpdir}")
        mp3 = str(files[0])

    print(f"✅ Audio saved: {mp3}")
    return mp3


def transcribe(audio_path: str, client: OpenAI) -> list[dict]:
    """Whisper API でセグメント + ワード単位の文字起こしを取得する。"""
    print("🎙️  Transcribing with Whisper API (word-level timestamps)...")

    with open(audio_path, "rb") as f:
        response = client.audio.transcriptions.create(
            model="whisper-1",
            file=f,
            language="ja",
            response_format="verbose_json",
            timestamp_granularities=["word", "segment"],
        )

    # Use segments for lyric grouping; use word timestamps for precise boundary
    # Build a lookup: segment index → list of word timestamps
    word_map: dict[int, list[dict]] = {}
    if hasattr(response, "words") and response.words:
        for word in response.words:
            # Find which segment this word belongs to
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

        # Use first/last word timestamps if available for precision
        words = word_map.get(i, [])
        if words:
            seg_start = round(float(words[0]["start"]), 2)
            seg_end = round(float(words[-1]["end"]), 2)
        else:
            seg_start = round(float(seg.start), 2)
            seg_end = round(float(seg.end), 2)

        segments.append({
            "start": seg_start,
            "end": seg_end,
            "text": text,
            "words": words,
        })

    print(f"✅ Got {len(segments)} segments from Whisper")
    return segments


def batch_analyze(
    segments: list[dict],
    rapper1: str,
    rapper2: str,
    client: OpenAI,
) -> list[dict]:
    """
    GPT-4o で全セグメントを一括分析。
    伝説的なヒップホップライターとして韻構造・サンプリング・パンチラインを解説。
    Returns: [{"start": float, "end": float, "lyric": str, "explanation": str}, ...]
    """
    # Build numbered transcript for GPT-4o
    numbered = "\n".join(
        [f"[{i+1}] ({seg['start']}s-{seg['end']}s) {seg['text']}" for i, seg in enumerate(segments)]
    )

    system = f"""あなたは伝説的なヒップホップライターであり、MCバトル・日本語ラップの最高権威です。
韻構造（母音韻・子音韻・内部韻・マルチシラブル韻）、サンプリング元、パンチラインの多重解釈、
バトルの文脈とディス対象、スラング・隠語の意味、フロウとリズムパターンを熟知しています。

バトル参加者: {rapper1} vs {rapper2}

以下の形式のJSONのみを返してください（余分なテキスト不要）:
{{
  "entries": [
    {{
      "index": 1,
      "explanation": "初心者でも理解できる1〜2文の解説。韻・パンチライン・ディスの意図・隠語をカバー。"
    }},
    ...
  ]
}}

解説の書き方:
- 踏んでいる韻があれば「〇〇と△△で□音の韻」と具体的に
- パンチラインは「〜という二重の意味を持つ」と多重解釈を
- 隠語・スラングは括弧内に意味を補足（例: シャブ（覚醒剤））
- 相手へのディスは誰への何の攻撃かを明示
- サンプリング・引用元があれば言及"""

    user = f"""以下のMCバトル文字起こし全ライン（{len(segments)}件）を解説してください:

{numbered}

各ラインのindex番号に対応したexplanationを返してください。"""

    try:
        resp = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            response_format={"type": "json_object"},
            max_tokens=4000,
            temperature=0.4,
        )
        result = json.loads(resp.choices[0].message.content)
        entries_map = {e["index"]: e["explanation"] for e in result.get("entries", [])}
    except Exception as e:
        print(f"  ⚠️  Batch analysis failed: {e}")
        entries_map = {}

    # Build final output
    output = []
    for i, seg in enumerate(segments):
        explanation = entries_map.get(i + 1, "")
        if not explanation:
            # Fallback: single call for this segment
            explanation = single_explain(seg, rapper1, rapper2, client)

        output.append({
            "start": seg["start"],
            "end": seg["end"],
            "lyric": seg["text"],
            "explanation": explanation,
        })

    return output


def single_explain(seg: dict, rapper1: str, rapper2: str, client: OpenAI) -> str:
    """単一セグメントのフォールバック解説。"""
    try:
        resp = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "system",
                    "content": f"伝説的なヒップホップライター。{rapper1} vs {rapper2}のバトルラインを初心者向けに1〜2文で解説。韻・パンチライン・隠語を含めること。",
                },
                {
                    "role": "user",
                    "content": f"「{seg['text']}」",
                },
            ],
            max_tokens=150,
            temperature=0.4,
        )
        return resp.choices[0].message.content.strip()
    except Exception as e:
        print(f"  ⚠️  Single explain failed: {e}")
        return ""


def main():
    parser = argparse.ArgumentParser(
        description="MCバトル動画をWhisper+GPT-4oで解析してJSONを出力"
    )
    parser.add_argument("url", help="YouTube URL")
    parser.add_argument("output", help="出力JSONファイルパス (例: battle.json)")
    parser.add_argument("--rapper1", default="MC1", help="1人目のMC名")
    parser.add_argument("--rapper2", default="MC2", help="2人目のMC名")
    parser.add_argument("--start", type=int, default=0, help="開始時間（秒） デフォルト=0")
    parser.add_argument(
        "--skip-download",
        metavar="AUDIO_PATH",
        help="既存のMP3を使用してダウンロードをスキップ（デバッグ用）",
    )
    args = parser.parse_args()

    client = get_client()

    # --- Step 1: Download ---
    if args.skip_download:
        audio_path = args.skip_download
        print(f"⏩ Skipping download, using: {audio_path}")
    else:
        audio_path = download_audio(args.url, args.start)

    # --- Step 2: Transcribe with word-level timestamps ---
    segments = transcribe(audio_path, client)
    if not segments:
        print("❌ 文字起こし結果が空です。音声ファイルを確認してください。")
        sys.exit(1)

    # --- Step 3: Batch analyze with GPT-4o ---
    print(f"\n🔍 Analyzing {len(segments)} segments with GPT-4o (batch)...")
    entries = batch_analyze(segments, args.rapper1, args.rapper2, client)

    # --- Step 4: Write output ---
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(entries, f, ensure_ascii=False, indent=2)

    print(f"\n✅ 完了！ {len(entries)}件 → {output_path}")
    print("\nXcodeにコピーする場合:")
    print(f"  cp {output_path} ~/Rap/MCBattleApp/MCBattleApp/Resources/battle.json")


if __name__ == "__main__":
    main()
