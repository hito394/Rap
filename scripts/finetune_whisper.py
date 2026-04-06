"""
Whisperファインチューン — 日本語ラップ特化

OpenAIのWhisper APIは直接fine-tuningできないため、
HuggingFaceのopenai/whisper-largeをローカルでfine-tuneする。

必要環境:
  - GPU (VRAM 8GB以上推奨) または Apple Silicon Mac (MPS)
  - pip install transformers datasets accelerate evaluate jiwer torch torchaudio

使い方:
  python finetune_whisper.py --prepare   # データセット準備のみ
  python finetune_whisper.py --train     # 学習開始
  python finetune_whisper.py --test      # 学習済みモデルでテスト

出力:
  models/whisper-rap-ja/  ... ファインチューン済みモデル

サーバーへの組み込み:
  server.py の whisper_transcribe() に fine-tuned モデルパスを指定する
"""

import argparse
import json
import os
import sys
from pathlib import Path

AUDIO_DIR = Path("data/raw_audio")
TRANSCRIPT_DIR = Path("data/raw_transcripts")
DATASET_DIR = Path("data/whisper_dataset")
MODEL_OUTPUT_DIR = Path("models/whisper-rap-ja")

BASE_MODEL = "openai/whisper-large-v3-turbo"  # 軽量でfine-tune向き


# ---------------------------------------------------------------------------
# データセット準備
# ---------------------------------------------------------------------------

def prepare_dataset():
    """音声ファイルと対応する字幕からHuggingFace Datasetを作成"""
    try:
        from datasets import Dataset, Audio
    except ImportError:
        print("pip install datasets が必要です")
        sys.exit(1)

    DATASET_DIR.mkdir(parents=True, exist_ok=True)

    pairs = []
    audio_files = list(AUDIO_DIR.glob("*.mp3")) + list(AUDIO_DIR.glob("*.wav"))

    print(f"音声ファイル: {len(audio_files)} 件")

    for audio_path in audio_files:
        vid = audio_path.stem
        transcript_path = TRANSCRIPT_DIR / f"{vid}.json"
        if not transcript_path.exists():
            continue

        record = json.loads(transcript_path.read_text())
        segments = record.get("segments", [])
        if not segments:
            continue

        # 全セグメントのテキストを結合
        full_text = " ".join(s["text"] for s in segments)
        full_text = full_text.strip()

        if len(full_text) < 50:
            continue

        pairs.append({
            "audio": str(audio_path.resolve()),
            "text": full_text,
            "video_id": vid,
            "title": record.get("title", ""),
        })

    print(f"有効なペア: {len(pairs)} 件")

    if len(pairs) == 0:
        print("\n⚠ 音声ファイルがありません。")
        print("  collect_training_data.py --audio を実行して音声も収集してください。")
        return

    # train / test 分割
    split = max(1, int(len(pairs) * 0.9))
    train_data = pairs[:split]
    test_data = pairs[split:]

    # 保存
    dataset_info = {
        "train_count": len(train_data),
        "test_count": len(test_data),
        "base_model": BASE_MODEL,
    }
    (DATASET_DIR / "info.json").write_text(json.dumps(dataset_info, ensure_ascii=False, indent=2))
    (DATASET_DIR / "train.jsonl").write_text("\n".join(json.dumps(p, ensure_ascii=False) for p in train_data))
    (DATASET_DIR / "test.jsonl").write_text("\n".join(json.dumps(p, ensure_ascii=False) for p in test_data))

    print(f"✅ 学習: {len(train_data)} 件")
    print(f"✅ テスト: {len(test_data)} 件")
    print(f"  保存先: {DATASET_DIR.resolve()}")


# ---------------------------------------------------------------------------
# Fine-tuning
# ---------------------------------------------------------------------------

def train():
    try:
        import torch
        from transformers import (
            WhisperProcessor,
            WhisperForConditionalGeneration,
            Seq2SeqTrainer,
            Seq2SeqTrainingArguments,
        )
        from datasets import Dataset, Audio
        import evaluate
    except ImportError:
        print("pip install transformers datasets evaluate accelerate torch torchaudio が必要です")
        sys.exit(1)

    # デバイス選択
    if torch.cuda.is_available():
        device = "cuda"
    elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
        device = "mps"
    else:
        device = "cpu"
        print("⚠ GPU/MPSが使えません。CPU学習は非常に遅いです。")

    print(f"\nデバイス: {device}")
    print(f"ベースモデル: {BASE_MODEL}")

    # データ読み込み
    train_path = DATASET_DIR / "train.jsonl"
    if not train_path.exists():
        print("❌ データセットが見つかりません。先に --prepare を実行してください。")
        sys.exit(1)

    train_records = [json.loads(l) for l in train_path.read_text().splitlines() if l.strip()]
    print(f"学習データ: {len(train_records)} 件")

    # プロセッサ・モデル読み込み
    print(f"\nモデル読み込み中...")
    processor = WhisperProcessor.from_pretrained(BASE_MODEL, language="ja", task="transcribe")
    model = WhisperForConditionalGeneration.from_pretrained(BASE_MODEL)
    model.config.forced_decoder_ids = processor.get_decoder_prompt_ids(language="ja", task="transcribe")

    # Dataset作成
    def load_audio_sample(record):
        import torchaudio
        waveform, sr = torchaudio.load(record["audio"])
        # モノラル変換
        if waveform.shape[0] > 1:
            waveform = waveform.mean(dim=0, keepdim=True)
        # 16kHzリサンプリング
        if sr != 16000:
            resampler = torchaudio.transforms.Resample(sr, 16000)
            waveform = resampler(waveform)
        return waveform.squeeze().numpy(), record["text"]

    def preprocess(batch):
        audio, text = load_audio_sample(batch)
        inputs = processor(audio, sampling_rate=16000, return_tensors="pt")
        batch["input_features"] = inputs.input_features[0]
        labels = processor.tokenizer(text, return_tensors="pt")
        batch["labels"] = labels.input_ids[0]
        return batch

    # HuggingFace Dataset
    raw_dataset = Dataset.from_list(train_records)
    processed = raw_dataset.map(preprocess, remove_columns=raw_dataset.column_names)

    MODEL_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # 学習設定
    training_args = Seq2SeqTrainingArguments(
        output_dir=str(MODEL_OUTPUT_DIR),
        num_train_epochs=3,
        per_device_train_batch_size=4 if device != "cpu" else 2,
        gradient_accumulation_steps=2,
        learning_rate=1e-5,
        warmup_steps=50,
        predict_with_generate=True,
        generation_max_length=225,
        fp16=(device == "cuda"),
        save_strategy="epoch",
        logging_steps=10,
        report_to="none",
        push_to_hub=False,
    )

    trainer = Seq2SeqTrainer(
        model=model,
        args=training_args,
        train_dataset=processed,
        tokenizer=processor.feature_extractor,
    )

    print("\nFine-tuning開始...\n")
    trainer.train()

    # 保存
    model.save_pretrained(str(MODEL_OUTPUT_DIR))
    processor.save_pretrained(str(MODEL_OUTPUT_DIR))
    print(f"\n✅ モデル保存: {MODEL_OUTPUT_DIR.resolve()}")
    print(f"\n📝 server.py の WHISPER_MODEL_PATH を以下に設定してください:")
    print(f'   WHISPER_MODEL_PATH = "{MODEL_OUTPUT_DIR.resolve()}"')


# ---------------------------------------------------------------------------
# テスト
# ---------------------------------------------------------------------------

def test_model(audio_path: str | None = None):
    try:
        import torch
        from transformers import WhisperProcessor, WhisperForConditionalGeneration
        import torchaudio
    except ImportError:
        print("transformers, torch, torchaudio が必要です")
        sys.exit(1)

    model_path = str(MODEL_OUTPUT_DIR) if MODEL_OUTPUT_DIR.exists() else BASE_MODEL
    print(f"モデル: {model_path}")

    processor = WhisperProcessor.from_pretrained(model_path, language="ja", task="transcribe")
    model = WhisperForConditionalGeneration.from_pretrained(model_path)

    # テスト音声
    if not audio_path:
        test_files = list(AUDIO_DIR.glob("*.mp3"))[:1]
        if not test_files:
            print("テスト用音声ファイルがありません。--test <audio_path> で指定してください。")
            return
        audio_path = str(test_files[0])

    print(f"テスト音声: {audio_path}")
    waveform, sr = torchaudio.load(audio_path)
    if waveform.shape[0] > 1:
        waveform = waveform.mean(dim=0, keepdim=True)
    if sr != 16000:
        waveform = torchaudio.transforms.Resample(sr, 16000)(waveform)

    inputs = processor(waveform.squeeze().numpy(), sampling_rate=16000, return_tensors="pt")
    with torch.no_grad():
        ids = model.generate(inputs["input_features"])

    text = processor.batch_decode(ids, skip_special_tokens=True)[0]
    print(f"\n文字起こし結果:\n{text}")


# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare", action="store_true", help="データセット準備")
    parser.add_argument("--train", action="store_true", help="Fine-tuning実行")
    parser.add_argument("--test", nargs="?", const="", metavar="AUDIO_PATH",
                        help="学習済みモデルでテスト")
    args = parser.parse_args()

    if args.prepare:
        prepare_dataset()
    elif args.train:
        train()
    elif args.test is not None:
        test_model(args.test if args.test else None)
    else:
        parser.print_help()
        print("\n手順:")
        print("  1. python collect_training_data.py --audio   # データ収集（音声込み）")
        print("  2. python finetune_whisper.py --prepare       # データセット準備")
        print("  3. python finetune_whisper.py --train         # Fine-tuning")
        print("  4. python finetune_whisper.py --test          # 動作確認")


if __name__ == "__main__":
    main()
