#!/usr/bin/env python3
"""
analyze_battle.py - YouTube MCバトル動画 → Whisper API → GPT-4o → JSON

Usage:
  python analyze_battle.py URL output.json --rapper1 NAME1 --rapper2 NAME2 [--start SECONDS]

Example:
  python analyze_battle.py 'https://youtu.be/3D6KUgNDn40' battle.json \
      --rapper1 'T-Pablow' --rapper2 'R-指定' --start 30
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
        # ffmpeg に SS を渡して指定秒からトリム
        cmd += ["--postprocessor-args", f"ffmpeg:-ss {start}"]

    cmd.append(url)

    print(f"⬇️  Downloading audio from {url} (start={start}s)...")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stderr)
        raise RuntimeError(f"yt-dlp failed:\n{result.stderr}")

    mp3 = os.path.join(tmpdir, "audio.mp3")
    if not os.path.exists(mp3):
        # yt-dlp のバージョンによってファイル名が変わる場合
        files = list(Path(tmpdir).glob("*.mp3"))
        if not files:
            raise FileNotFoundError(f"MP3 not found in {tmpdir}")
        mp3 = str(files[0])

    print(f"✅ Audio saved: {mp3}")
    return mp3


def transcribe(audio_path: str, client: OpenAI) -> list[dict]:
    """Whisper API でセグメント単位の文字起こしを取得する。"""
    print("🎙️  Transcribing with Whisper API...")

    with open(audio_path, "rb") as f:
        response = client.audio.transcriptions.create(
            model="whisper-1",
            file=f,
            language="ja",
            response_format="verbose_json",
            timestamp_granularities=["segment"],
        )

    segments = []
    for seg in response.segments:
        text = seg.text.strip()
        if text:
            segments.append({
                "start": round(float(seg.start), 2),
                "end": round(float(seg.end), 2),
                "text": text,
            })

    print(f"✅ Got {len(segments)} segments from Whisper")
    return segments


def analyze_segment(
    seg: dict,
    all_segments: list[dict],
    rapper1: str,
    rapper2: str,
    client: OpenAI,
) -> dict:
    """GPT-4o で1セグメントの韻・パンチライン・文脈を分析する。"""
    transcript_ctx = "\n".join(
        [f"[{s['start']:.1f}s] {s['text']}" for s in all_segments[:30]]
    )

    system = f"""あなたは日本語MCバトル・ヒップホップの最高権威です。
バトル参加者: {rapper1} vs {rapper2}

以下のJSONのみを返してください（余分なテキスト不要）:
{{
  "rhyme_pattern": "韻の種類（母音韻/子音韻/内部韻/マルチシラブル韻/フリーフロウ等）",
  "rhyme_words": ["踏んでいる言葉1", "言葉2"],
  "rhyme_explanation": "なぜこれが韻を踏んでいるか（音韻的説明）",
  "context": "バトル内での文脈・意図・誰への攻撃か・どんな状況か",
  "sampling": "サンプリング・引用・アンサーラップがあれば記述、なければnull",
  "difficulty": "easy/medium/hard（リリシズムの高度さ）",
  "keywords": ["注目キーワード1", "キーワード2"],
  "deep_dive_hint": "このラインをさらに深く掘り下げる切り口"
}}"""

    user = f"""バトル全体の文字起こし（参考）:
{transcript_ctx}

分析対象:
時間: {seg['start']}s〜{seg['end']}s
テキスト: 「{seg['text']}」

このラインのJSON分析を返してください。"""

    try:
        resp = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            response_format={"type": "json_object"},
            max_tokens=400,
            temperature=0.3,
        )
        return json.loads(resp.choices[0].message.content)
    except Exception as e:
        print(f"  ⚠️  Analysis failed: {e}")
        return {
            "rhyme_pattern": "不明",
            "rhyme_words": [],
            "rhyme_explanation": "",
            "context": "",
            "sampling": None,
            "difficulty": "medium",
            "keywords": [],
            "deep_dive_hint": "",
        }


def add_explanation(entry: dict, all_entries: list[dict], rapper1: str, rapper2: str, client: OpenAI) -> str:
    """初心者向けの短い解説文を GPT-4o で生成する。"""
    ctx = "\n".join([f"[{e['start']}s] {e['lyric']}" for e in all_entries[:20]])

    try:
        resp = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "system",
                    "content": f"日本語MCバトル解説者。{rapper1} vs {rapper2}のバトルを初心者向けに1〜2文で解説。",
                },
                {
                    "role": "user",
                    "content": f"このラインを解説:\n「{entry['lyric']}」\n\n文脈:\n{ctx[:600]}",
                },
            ],
            max_tokens=120,
            temperature=0.5,
        )
        return resp.choices[0].message.content.strip()
    except Exception as e:
        print(f"  ⚠️  Explanation failed: {e}")
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

    # --- Step 2: Transcribe ---
    segments = transcribe(audio_path, client)
    if not segments:
        print("❌ 文字起こし結果が空です。音声ファイルを確認してください。")
        sys.exit(1)

    # --- Step 3: Build initial entries ---
    entries = [
        {
            "id": i + 1,
            "start": seg["start"],
            "end": seg["end"],
            "lyric": seg["text"],
            "explanation": "",
            "analysis": None,
        }
        for i, seg in enumerate(segments)
    ]

    # --- Step 4: Analyze each segment ---
    print(f"\n🔍 Analyzing {len(entries)} segments with GPT-4o...")
    for i, (entry, seg) in enumerate(zip(entries, segments)):
        print(f"  [{i+1}/{len(entries)}] {seg['text'][:40]}...")
        entry["analysis"] = analyze_segment(seg, segments, args.rapper1, args.rapper2, client)

    # --- Step 5: Add plain explanations ---
    print("\n📝 Adding plain-language explanations...")
    for i, entry in enumerate(entries):
        print(f"  [{i+1}/{len(entries)}] ...")
        entry["explanation"] = add_explanation(entry, entries, args.rapper1, args.rapper2, client)

    # --- Step 6: Write output ---
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(entries, f, ensure_ascii=False, indent=2)

    print(f"\n✅ 完了！ {len(entries)}件 → {output_path}")
    print("\nXcodeにコピーする場合:")
    print(f"  cp {output_path} /Users/shimazakihitoshi/Rap/MCBattleApp/MCBattleApp/Resources/battle.json")


if __name__ == "__main__":
    main()
