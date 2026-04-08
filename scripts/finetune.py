"""
Step 3: OpenAIにファインチューニングジョブを投入し、完了まで監視する

使い方:
  python finetune.py              # ジョブ投入 + 監視
  python finetune.py --status    # 既存ジョブの状態確認
  python finetune.py --list      # モデル一覧

環境変数:
  OPENAI_API_KEY  ... OpenAI APIキー（必須）
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

try:
    from openai import OpenAI
except ImportError:
    print("openai パッケージが必要です: pip install openai")
    sys.exit(1)

TRAIN_PATH = Path("data/finetune_rap_explain_train.jsonl")
VAL_PATH = Path("data/finetune_rap_explain_val.jsonl")
STATE_PATH = Path("data/finetune_state.json")

BASE_MODEL = "gpt-4o-mini-2024-07-18"  # fine-tuning対応の最新mini

# ---------------------------------------------------------------------------

def load_state() -> dict:
    if STATE_PATH.exists():
        return json.loads(STATE_PATH.read_text())
    return {}

def save_state(state: dict):
    STATE_PATH.write_text(json.dumps(state, indent=2, ensure_ascii=False))


def upload_file(client: OpenAI, path: Path, purpose: str = "fine-tune") -> str:
    print(f"  アップロード中: {path.name} ({path.stat().st_size // 1024} KB)")
    with open(path, "rb") as f:
        response = client.files.create(file=f, purpose=purpose)
    print(f"  → file_id: {response.id}")
    return response.id


def submit_job(client: OpenAI) -> str:
    if not TRAIN_PATH.exists():
        print("❌ 学習データが見つかりません。先に prepare_finetune.py を実行してください。")
        sys.exit(1)

    # データ件数チェック
    train_lines = [l for l in TRAIN_PATH.read_text().splitlines() if l.strip()]
    train_count = len(train_lines)
    print(f"\n学習データ: {train_count} 件")
    if train_count < 10:
        print("❌ OpenAIのfine-tuningには最低10件必要です。データを追加してください。")
        sys.exit(1)

    # MAX_TRAIN_SAMPLES でコストを抑える（Noneで全件使用）
    MAX_TRAIN_SAMPLES = int(os.environ.get("MAX_TRAIN_SAMPLES", 0)) or None
    if MAX_TRAIN_SAMPLES and train_count > MAX_TRAIN_SAMPLES:
        import random
        sampled = random.sample(train_lines, MAX_TRAIN_SAMPLES)
        tmp_path = TRAIN_PATH.parent / "finetune_rap_explain_train_sampled.jsonl"
        tmp_path.write_text("\n".join(sampled))
        print(f"  ⚡ {MAX_TRAIN_SAMPLES}件にサンプリング（コスト削減）→ {tmp_path.name}")
        actual_train_path = tmp_path
    else:
        actual_train_path = TRAIN_PATH

    state = load_state()

    # ファイルアップロード
    print("\n[1/3] ファイルアップロード")
    train_file_id = upload_file(client, actual_train_path)
    val_file_id = upload_file(client, VAL_PATH) if VAL_PATH.exists() else None

    # ジョブ投入
    print("\n[2/3] Fine-tuningジョブ投入")
    kwargs = {
        "training_file": train_file_id,
        "model": BASE_MODEL,
        "hyperparameters": {
            "n_epochs": 3,
        },
        "suffix": "rap-explain",
    }
    if val_file_id:
        kwargs["validation_file"] = val_file_id

    job = client.fine_tuning.jobs.create(**kwargs)
    print(f"  ジョブID: {job.id}")
    print(f"  ステータス: {job.status}")

    state["job_id"] = job.id
    state["model"] = BASE_MODEL
    state["submitted_at"] = time.time()
    save_state(state)

    return job.id


def monitor_job(client: OpenAI, job_id: str):
    print(f"\n[3/3] 完了まで監視中 (job_id: {job_id})")
    print("  Ctrl+C で中断可能（ジョブは継続されます）\n")

    last_event_id = None
    check_interval = 30  # 30秒おきに確認

    try:
        while True:
            job = client.fine_tuning.jobs.retrieve(job_id)
            status = job.status

            # イベントログ取得
            events = client.fine_tuning.jobs.list_events(
                fine_tuning_job_id=job_id,
                limit=5,
            )
            for event in reversed(list(events.data)):
                if event.id != last_event_id:
                    ts = time.strftime("%H:%M:%S", time.localtime(event.created_at))
                    print(f"  [{ts}] {event.message}")
                    last_event_id = event.id

            if status == "succeeded":
                model_id = job.fine_tuned_model
                print(f"\n✅ Fine-tuning完了！")
                print(f"  モデルID: {model_id}")
                state = load_state()
                state["fine_tuned_model"] = model_id
                state["completed_at"] = time.time()
                save_state(state)

                print(f"\n📝 server.py を以下のモデルIDで更新してください:")
                print(f"  FINE_TUNED_MODEL = \"{model_id}\"")
                break

            elif status in ("failed", "cancelled"):
                print(f"\n❌ ジョブ {status}: {job.error}")
                break

            time.sleep(check_interval)

    except KeyboardInterrupt:
        print(f"\n監視を中断しました。ジョブは継続中です。")
        print(f"  再開: python finetune.py --status {job_id}")


def list_models(client: OpenAI):
    print("\n=== Fine-tunedモデル一覧 ===")
    models = client.models.list()
    rap_models = [m for m in models.data if "rap" in m.id or "ft:" in m.id]
    if not rap_models:
        print("  （なし）")
    for m in rap_models:
        print(f"  {m.id}")


def check_status(client: OpenAI, job_id: str | None = None):
    if not job_id:
        state = load_state()
        job_id = state.get("job_id")
        if not job_id:
            print("ジョブIDが見つかりません。先に python finetune.py でジョブを投入してください。")
            return

    job = client.fine_tuning.jobs.retrieve(job_id)
    print(f"\n=== ジョブステータス ===")
    print(f"  ID: {job.id}")
    print(f"  ステータス: {job.status}")
    print(f"  ベースモデル: {job.model}")
    if job.fine_tuned_model:
        print(f"  完成モデル: {job.fine_tuned_model}")
    if job.trained_tokens:
        print(f"  学習トークン: {job.trained_tokens:,}")


# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--status", nargs="?", const="", metavar="JOB_ID",
                        help="ジョブステータス確認")
    parser.add_argument("--list", action="store_true", help="モデル一覧")
    parser.add_argument("--monitor", metavar="JOB_ID", help="既存ジョブを監視")
    args = parser.parse_args()

    api_key = os.environ.get("OPENAI_API_KEY", "")
    if not api_key:
        print("❌ OPENAI_API_KEY が設定されていません。")
        print("   export OPENAI_API_KEY=sk-...")
        sys.exit(1)

    client = OpenAI(api_key=api_key)

    if args.list:
        list_models(client)
    elif args.status is not None:
        check_status(client, args.status if args.status else None)
    elif args.monitor:
        monitor_job(client, args.monitor)
    else:
        print(f"{'='*60}")
        print("ラップ解説AI Fine-tuning")
        print(f"ベースモデル: {BASE_MODEL}")
        print(f"{'='*60}")
        job_id = submit_job(client)
        monitor_job(client, job_id)


if __name__ == "__main__":
    main()
