"""
Step 1: YouTubeからラップ解説動画のトランスクリプトを収集する

使い方:
  python collect_training_data.py

出力:
  data/raw_transcripts/  ... 動画ごとのJSONファイル
  data/raw_audio/        ... Whisperファインチューン用の音声（--audio フラグ時）
"""

import argparse
import asyncio
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# 収集対象クエリ（解説・教育系コンテンツ）
# ---------------------------------------------------------------------------
SEARCH_QUERIES = [
    # 日本語ラップ解説
    "日本語ラップ 解説 ライム",
    "MCバトル 解説 フロー",
    "日本語ラップ フロー 技術 解説",
    "ラップ 韻 踏み方 解説",
    "ヒップホップ 用語 解説",
    "MCバトル ダジャレ ライム 解説",
    "日本語ラップ 歌詞 解説",
    "フリースタイルラップ 解説",
    # 英語ラップ解説（日本語解説）
    "ケンドリックラマー 解説 日本語",
    "エミネム ライム 解説",
    "ヒップホップ 歌詞 和訳 解説",
    # 英語ラップ技術解説
    "rap techniques explained multisyllabic rhyme",
    "rap flow patterns explained",
    "kendrick lamar rhyme scheme breakdown",
    "eminem wordplay explained",
    "rap battle techniques explained",
    "hip hop lyricism analysis",
    "internal rhyme rap explained",
    "double entendre rap explained",
    # MCバトル専門
    "mc battle lyric breakdown japanese",
    "UMB 解説 ライム",
    "KOK ラップバトル 解説",
]

OUTPUT_DIR = Path("data/raw_transcripts")
AUDIO_DIR = Path("data/raw_audio")
MAX_PER_QUERY = 5  # 1クエリあたりの最大取得数

# ---------------------------------------------------------------------------

def search_videos(query: str, limit: int) -> list[dict]:
    cmd = [
        "yt-dlp",
        f"ytsearch{limit}:{query}",
        "--dump-json",
        "--flat-playlist",
        "--no-download",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    videos = []
    for line in result.stdout.strip().splitlines():
        try:
            v = json.loads(line)
            videos.append({
                "id": v.get("id", ""),
                "title": v.get("title", ""),
                "channel": v.get("channel", v.get("uploader", "")),
                "duration": v.get("duration", 0),
                "query": query,
            })
        except json.JSONDecodeError:
            pass
    return videos


def fetch_transcript(video_id: str) -> list[dict] | None:
    """YouTube自動字幕またはCC字幕を取得"""
    cmd = [
        "yt-dlp",
        "--write-auto-subs",
        "--write-subs",
        "--sub-langs", "ja,ja-JP,en,en-US",
        "--sub-format", "json3",
        "--skip-download",
        "--output", f"/tmp/yt_sub_{video_id}",
        f"https://www.youtube.com/watch?v={video_id}",
    ]
    subprocess.run(cmd, capture_output=True, timeout=60)

    # ダウンロードされた字幕ファイルを探す
    for lang in ["ja", "ja-JP", "en", "en-US"]:
        for suffix in [f".{lang}.json3", f".{lang}-orig.json3"]:
            path = Path(f"/tmp/yt_sub_{video_id}{suffix}")
            if path.exists():
                try:
                    data = json.loads(path.read_text())
                    segments = []
                    for event in data.get("events", []):
                        start = event.get("tStartMs", 0) / 1000.0
                        dur = event.get("dDurationMs", 0) / 1000.0
                        segs = event.get("segs", [])
                        text = "".join(s.get("utf8", "") for s in segs).strip()
                        if text and text != "\n":
                            segments.append({
                                "start": round(start, 2),
                                "end": round(start + dur, 2),
                                "text": text,
                            })
                    # 一時ファイル削除
                    for p in Path("/tmp").glob(f"yt_sub_{video_id}*"):
                        p.unlink(missing_ok=True)
                    if segments:
                        return segments
                except Exception:
                    pass
    return None


def download_audio(video_id: str, out_dir: Path) -> Path | None:
    """Whisperファインチューン用に音声をダウンロード（最大10分）"""
    out_path = out_dir / f"{video_id}.mp3"
    if out_path.exists():
        return out_path
    cmd = [
        "yt-dlp",
        "-x", "--audio-format", "mp3",
        "--audio-quality", "5",
        "--postprocessor-args", "-t 600",  # 10分でカット
        "-o", str(out_path),
        f"https://www.youtube.com/watch?v={video_id}",
    ]
    result = subprocess.run(cmd, capture_output=True, timeout=120)
    return out_path if out_path.exists() else None


def collect(include_audio: bool = False):
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    if include_audio:
        AUDIO_DIR.mkdir(parents=True, exist_ok=True)

    seen_ids = {p.stem for p in OUTPUT_DIR.glob("*.json")}
    all_videos = []

    print(f"\n{'='*60}")
    print("YouTube解説動画 トランスクリプト収集")
    print(f"クエリ数: {len(SEARCH_QUERIES)} / 1件あたり最大: {MAX_PER_QUERY}")
    print(f"{'='*60}\n")

    # 検索
    for i, query in enumerate(SEARCH_QUERIES, 1):
        print(f"[{i}/{len(SEARCH_QUERIES)}] 検索中: {query}")
        try:
            videos = search_videos(query, MAX_PER_QUERY)
            new = [v for v in videos if v["id"] and v["id"] not in seen_ids]
            all_videos.extend(new)
            seen_ids.update(v["id"] for v in new)
            print(f"  → {len(new)} 件の新規動画")
        except Exception as e:
            print(f"  ⚠ エラー: {e}")

    print(f"\n合計 {len(all_videos)} 件の動画からトランスクリプト取得開始\n")

    success = 0
    for i, video in enumerate(all_videos, 1):
        vid = video["id"]
        title = video["title"][:60]
        print(f"[{i}/{len(all_videos)}] {title} ({vid})")

        out_path = OUTPUT_DIR / f"{vid}.json"
        if out_path.exists():
            print("  → スキップ（既存）")
            success += 1
            continue

        try:
            segments = fetch_transcript(vid)
            if not segments:
                print("  → 字幕なし、スキップ")
                continue

            duration = video.get("duration", 0)
            # 短すぎる（3分未満）・長すぎる（2時間超）はスキップ
            if duration and (duration < 180 or duration > 7200):
                print(f"  → 長さ {duration}秒 のためスキップ")
                continue

            record = {
                "video_id": vid,
                "title": video["title"],
                "channel": video["channel"],
                "duration": duration,
                "query": video["query"],
                "segments": segments,
            }
            out_path.write_text(json.dumps(record, ensure_ascii=False, indent=2))
            success += 1
            print(f"  ✅ {len(segments)} セグメント保存")

            # 音声ダウンロード（オプション）
            if include_audio:
                audio_path = download_audio(vid, AUDIO_DIR)
                if audio_path:
                    print(f"  🎵 音声: {audio_path}")

        except subprocess.TimeoutExpired:
            print("  → タイムアウト")
        except Exception as e:
            print(f"  ⚠ エラー: {e}")

    print(f"\n{'='*60}")
    print(f"完了: {success}/{len(all_videos)} 件取得")
    print(f"保存先: {OUTPUT_DIR.resolve()}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", action="store_true", help="Whisper用音声もダウンロード")
    args = parser.parse_args()
    collect(include_audio=args.audio)
