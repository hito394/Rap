"""
Step 1: YouTubeからヒップホップ全般の解説動画トランスクリプトを収集する

使い方:
  python collect_training_data.py           # 全カテゴリ収集
  python collect_training_data.py --audio   # Whisper用音声も収集

出力:
  data/raw_transcripts/  ... 動画ごとのJSONファイル
  data/raw_audio/        ... Whisperファインチューン用の音声
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
# 収集対象クエリ — ヒップホップ全4要素 + 周辺文化を網羅
# ---------------------------------------------------------------------------
SEARCH_QUERIES = [
    # ── ラップ・MC技術（日本語） ──────────────────────────────────────────
    "日本語ラップ 解説 ライム",
    "MCバトル 解説 フロー",
    "日本語ラップ フロー 技術 解説",
    "ラップ 韻 踏み方 解説",
    "ヒップホップ 用語 解説",
    "MCバトル ダジャレ ライム 解説",
    "日本語ラップ 歌詞 解説",
    "フリースタイルラップ 解説",
    "ラップ パンチライン 解説",
    "ラップ ダブルミーニング 解説",
    "日本語ラップ 歴史 解説",

    # ── ラップ・MC技術（英語コンテンツ） ─────────────────────────────────
    "rap techniques explained multisyllabic rhyme",
    "rap flow patterns explained",
    "kendrick lamar rhyme scheme breakdown",
    "eminem wordplay explained",
    "rap battle techniques explained",
    "hip hop lyricism analysis",
    "internal rhyme rap explained",
    "double entendre rap explained",
    "rap punchline breakdown analysis",
    "storytelling in rap explained",
    "rap cadence and delivery explained",

    # ── MCバトル専門 ───────────────────────────────────────────────────────
    "mc battle lyric breakdown japanese",
    "UMB 解説 ライム",
    "KOK ラップバトル 解説",
    "フリースタイルダンジョン 解説",
    "高校生RAP選手権 解説",
    "mc battle rap analysis breakdown",
    "URL rap battle breakdown explained",
    "rap battle judging criteria explained",

    # ── 著名アーティスト解説（日本） ──────────────────────────────────────
    "ケンドリックラマー 解説 日本語",
    "エミネム ライム 解説",
    "ヒップホップ 歌詞 和訳 解説",
    "JAY-Z 歌詞 解説 日本語",
    "Nas Illmatic 解説",
    "Notorious BIG 解説 日本語",
    "Tupac 歌詞 解説 日本語",
    "ドレイク 解説 日本語",
    "カニエウェスト 解説 日本語",
    "漢 a.k.a. GAMI 解説",
    "T-PABLOW 解説 ラップ",
    "ZORN 歌詞 解説",
    "¥ellow Bucks 解説",
    "BIM 解説 ラップ",
    "Awich 解説",

    # ── ビートメイク・プロダクション ─────────────────────────────────────
    "ビートメイク 解説 ヒップホップ",
    "サンプリング 解説 ヒップホップ",
    "boom bap ビート 解説",
    "trap beat 作り方 解説",
    "hip hop production techniques explained",
    "sampling in hip hop explained",
    "boom bap vs trap explained",
    "lo-fi hip hop explained",
    "MPC drum machine hip hop explained",
    "808 bass hip hop explained",
    "J Dilla beatmaking style explained",
    "Madlib beatmaking explained",
    "Dr Dre production style explained",
    "Kanye West sampling explained",

    # ── DJ・ターンテーブリズム ────────────────────────────────────────────
    "DJ スクラッチ 解説 ヒップホップ",
    "ターンテーブリズム 解説",
    "hip hop dj techniques explained scratching",
    "turntablism history explained",
    "DJ battle explained hip hop",
    "breakbeat DJing explained",
    "DJ Kool Herc explained hip hop history",
    "DJ Premier scratching explained",

    # ── ブレイクダンス・Bボーイ文化 ───────────────────────────────────────
    "ブレイクダンス 解説 歴史",
    "Bボーイ 文化 解説",
    "breakdancing history explained",
    "bboy moves explained footwork",
    "powermoves breakdance explained",
    "hip hop dance styles explained",
    "popping locking explained hip hop",
    "breaking vs breakdancing explained",

    # ── グラフィティ・ストリートアート ────────────────────────────────────
    "グラフィティ 解説 ヒップホップ",
    "ストリートアート 文化 解説",
    "graffiti hip hop culture explained",
    "graffiti styles explained wildstyle",
    "graffiti tagging history hip hop",

    # ── ヒップホップ歴史・文化 ────────────────────────────────────────────
    "ヒップホップ 歴史 解説",
    "ヒップホップ 4要素 解説",
    "日本語ラップ 歴史 年表",
    "ヒップホップ 誕生 ブロンクス 解説",
    "hip hop history 1970s bronx explained",
    "golden age hip hop explained",
    "east coast west coast rap beef explained",
    "gangsta rap history explained",
    "conscious rap explained",
    "trap music history explained",
    "drill music explained",
    "mumble rap explained",
    "old school hip hop explained",
    "hip hop culture four elements explained",
    "hip hop fashion history explained streetwear",

    # ── 日本ヒップホップシーン ───────────────────────────────────────────
    "日本語ラップ シーン 解説 歴史",
    "日本 ヒップホップ 文化 解説",
    "BUDDHA BRAND 解説",
    "RHYMESTER 解説 歴史",
    "NITRO MICROPHONE UNDERGROUND 解説",
    "キングギドラ 解説",
    "日本 ストリートカルチャー ヒップホップ",

    # ── アルバム・名盤解説 ────────────────────────────────────────────────
    "Illmatic 解説 Nas 日本語",
    "Ready to Die 解説 日本語",
    "Me Against the World 解説",
    "All Eyez on Me 解説",
    "The Blueprint 解説 JAY-Z",
    "The College Dropout 解説 Kanye",
    "good kid maad city 解説 日本語",
    "To Pimp a Butterfly 解説 日本語",
    "Marshall Mathers LP 解説",
    "Enter the Wu-Tang 解説",

    # ── アーティスト関係性・クルー・師弟 ────────────────────────────────
    "日本語ラップ クルー 解説",
    "BAD HOP 解説 メンバー 歴史",
    "舐達麻 メンバー 成り立ち 解説",
    "ZEEBRA UZI 師弟関係 日本語ラップ",
    "ANARCHY RYUZO 解説",
    "G-FREAK FACTORY 解説",
    "STERUSS 仲間 クルー 解説",
    "日本語ラップ レーベル 解説",
    "PB 解説 ヒップホップ クルー",
    "KANDYTOWN 解説 メンバー",
    "NITRO MICROPHONE UNDERGROUND クルー 解説",
    "Da.Me.Records 解説",
    "IJE 解説 日本語ラップ",
    "THA BLUE HERB 解説",
    "BUDDHA BRAND クルー 解説",
    "WU-TANG CLAN members explained roles",
    "Odd Future crew explained Tyler the Creator",
    "TDE label explained Kendrick Lamar",
    "Cash Money Records history explained",
    "Roc-A-Fella Records history Jay-Z",
    "Aftermath Records Dr Dre history",

    # ── ビーフ・抗争の歴史 ────────────────────────────────────────────────
    "日本語ラップ ビーフ 歴史 解説",
    "舐達麻 BAD HOP ビーフ 解説",
    "KNIZZ SEEDA ビーフ 解説",
    "般若 ビーフ 解説 歴史",
    "日本語ラップ 炎上 対立 解説",
    "MCバトル ビーフ 発展 解説",
    "drake kendrick lamar beef explained 2024",
    "jay-z nas beef ether explained",
    "50 cent ja rule beef explained",
    "meek mill drake beef explained",
    "east west coast beef explained tupac biggie",

    # ── 伝説のパンチライン・名場面 ───────────────────────────────────────
    "日本語ラップ 伝説 パンチライン 解説",
    "晋平太 漢 バトル 解説",
    "MCバトル 名場面 伝説 解説",
    "R指定 伝説 バトル 解説",
    "般若 パンチライン 解説",
    "T-PABLOW 伝説ライン 解説",
    "ラップ 震災 311 歌詞 解説",
    "ヒップホップ 社会 政治 歌詞 解説",
    "kendrick lamar control verse explained",
    "eminem lose yourself meaning explained",
    "nas ny state of mind meaning explained",
    "jay-z 99 problems meaning explained",
    "biggie juicy lyrics meaning explained",

    # ── 地域スラング・隠語 ────────────────────────────────────────────────
    "ヒップホップ スラング 解説 隠語",
    "川崎 ヒップホップ スラング 解説",
    "大阪 ラップ 方言 解説",
    "沖縄 ヒップホップ 解説",
    "ラップ 隠語 ドラッグ 歌詞 解説",
    "ストリート スラング 日本語ラップ 解説",
    "ヒップホップ 刑務所 ムショ 歌詞 解説",
    "hip hop slang dictionary explained",
    "drug slang in rap lyrics explained",
    "prison slang hip hop explained",
    "hood slang rap explained",
    "atlanta slang trap explained",
    "new york slang hip hop explained",

    # ── プロデューサー・機材・ビートのトレンド ────────────────────────────
    "BACHLOGIC 解説 プロデューサー",
    "DJ PMX 解説 ウエッサイ",
    "stillichimiya ビート 解説",
    "YOGI 解説 プロデューサー 日本語ラップ",
    "MPC 2000 3000 ヒップホップ 解説",
    "SP-1200 サンプラー 解説 ヒップホップ",
    "Roland TR-808 ヒップホップ 解説 歴史",
    "ビートメイク 機材 歴史 解説",
    "MPC60 SP1200 drum machine hip hop history",
    "Roland 808 tr808 history hip hop explained",
    "akai mpc history beatmaking explained",
    "fl studio logic ableton hip hop production",
    "J Dilla MPC3000 explained beatmaking",
    "boom bap vs trap production explained",
    "lo-fi hip hop production explained",
    "phonk music explained history",
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


def whisper_transcribe(audio_path: str) -> tuple[list[dict], bool]:
    """ローカルWhisperで音声を文字起こし。(segments, whisper_available) を返す"""
    try:
        import whisper
    except ImportError:
        print("  ⚠ openai-whisper未インストール → 音声は保存済み、後で文字起こし可能")
        print("     pip install openai-whisper")
        return [], False  # whisper使えない
    print("  🎙️  Whisper(base)で文字起こし中...")
    model = whisper.load_model("base")
    result = model.transcribe(audio_path, language="ja", word_timestamps=False)
    segments = []
    for seg in result.get("segments", []):
        text = seg.get("text", "").strip()
        if text:
            segments.append({
                "start": round(seg["start"], 2),
                "end": round(seg["end"], 2),
                "text": text,
            })
    return segments, True


def collect(include_audio: bool = False):
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)

    seen_ids = {p.stem for p in OUTPUT_DIR.glob("*.json")}
    all_videos = []

    print(f"\n{'='*60}")
    print("YouTube解説動画 トランスクリプト収集")
    print(f"クエリ数: {len(SEARCH_QUERIES)} / 1件あたり最大: {MAX_PER_QUERY}")
    print(f"スキップ条件: 60秒未満 / 7200秒超 のみ（字幕なしはWhisperで補完）")
    print(f"{'='*60}\n")

    for i, query in enumerate(SEARCH_QUERIES, 1):
        print(f"[{i}/{len(SEARCH_QUERIES)}] 検索中: {query}")
        try:
            videos = search_videos(query, MAX_PER_QUERY)
            new = [v for v in videos if v["id"] and v["id"] not in seen_ids]
            all_videos.extend(new)
            seen_ids.update(v["id"] for v in new)
            print(f"  → {len(new)} 件の新規動画")
        except Exception as e:
            print(f"  ⚠ 検索エラー: {e}")

    print(f"\n合計 {len(all_videos)} 件の動画を処理開始\n")

    success = 0
    skipped = 0

    for i, video in enumerate(all_videos, 1):
        vid = video["id"]
        duration = video.get("duration", 0)
        title = video["title"][:60]
        print(f"[{i}/{len(all_videos)}] {title}")
        print(f"  ID:{vid}  長さ:{duration}秒  クエリ:{video['query'][:30]}")

        out_path = OUTPUT_DIR / f"{vid}.json"
        if out_path.exists():
            print("  → スキップ（既存）")
            success += 1
            continue

        if duration and duration < 60:
            print(f"  ✗ スキップ: {duration}秒 < 60秒（短すぎる）")
            skipped += 1
            continue
        if duration and duration > 7200:
            print(f"  ✗ スキップ: {duration}秒 > 7200秒（2時間超）")
            skipped += 1
            continue

        try:
            segments = []
            needs_whisper = False
            audio_saved = None

            # Step 1: YouTube字幕
            print("  [字幕] YouTube字幕を取得中...")
            segments = fetch_transcript(vid)
            if segments:
                print(f"  ✅ 字幕: {len(segments)} セグメント取得")
            else:
                print("  ⚡ 字幕なし → 音声ダウンロード開始...")
                audio_saved = download_audio(vid, AUDIO_DIR)
                if audio_saved:
                    print(f"  🎵 音声DL完了: {audio_saved.name}")
                    # Step 2: Whisper文字起こし
                    segments, whisper_ok = whisper_transcribe(str(audio_saved))
                    if segments:
                        print(f"  ✅ Whisper: {len(segments)} セグメント取得")
                    elif not whisper_ok:
                        # whisper未インストール → segmentsは空だが音声は保存済み
                        needs_whisper = True
                        print("  📦 音声保存済み（whisperインストール後に再実行で文字起こし可能）")
                    else:
                        print("  ⚠ Whisper: 文字起こし結果が空（セグメントなしで保存）")
                else:
                    print("  ⚠ 音声DL失敗（メタデータのみ保存）")

            # セグメントの有無にかかわらず必ず保存
            record = {
                "video_id": vid,
                "title": video["title"],
                "channel": video["channel"],
                "duration": duration,
                "query": video["query"],
                "segments": segments,
                "needs_whisper": needs_whisper,
                "audio_path": str(audio_saved) if audio_saved else None,
            }
            out_path.write_text(json.dumps(record, ensure_ascii=False, indent=2))
            success += 1
            seg_label = f"{len(segments)} segs" if segments else "セグメントなし（音声保存済み）" if audio_saved else "メタデータのみ"
            print(f"  💾 保存完了: {seg_label}")

            if include_audio and not audio_saved:
                dl = download_audio(vid, AUDIO_DIR)
                if dl:
                    print(f"  🎵 音声追加保存: {dl.name}")

        except subprocess.TimeoutExpired:
            print(f"  ✗ タイムアウト（メタデータのみ保存試行）")
            record = {"video_id": vid, "title": video["title"], "channel": video["channel"],
                      "duration": duration, "query": video["query"], "segments": [],
                      "needs_whisper": True, "audio_path": None}
            out_path.write_text(json.dumps(record, ensure_ascii=False, indent=2))
            success += 1
        except Exception as e:
            print(f"  ✗ エラー: {e}（スキップ）")
            skipped += 1

    print(f"\n{'='*60}")
    print(f"完了: 保存 {success} 件 / スキップ {skipped} 件 / 合計 {len(all_videos)} 件")
    needs = sum(1 for p in OUTPUT_DIR.glob("*.json")
                if json.loads(p.read_text()).get("needs_whisper"))
    if needs:
        print(f"⚡ 要Whisper文字起こし: {needs} 件 → pip install openai-whisper 後に再実行")
    print(f"保存先: {OUTPUT_DIR.resolve()}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", action="store_true", help="Whisper用音声もダウンロード")
    args = parser.parse_args()
    collect(include_audio=args.audio)
