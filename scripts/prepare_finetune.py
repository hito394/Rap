"""
Step 2: 収集したトランスクリプトをOpenAI fine-tuning用JSONLに変換する

使い方:
  python prepare_finetune.py

出力:
  data/finetune_rap_explain.jsonl   ... ラップ解説AIのファインチューンデータ
  data/finetune_whisper_pairs.jsonl ... Whisperファインチューン用の音声-テキストペア情報
"""

import json
import random
import re
from pathlib import Path

TRANSCRIPT_DIR = Path("data/raw_transcripts")
OUTPUT_DIR = Path("data")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

SYSTEM_PROMPT = """あなたは日本語ラップ・ヒップホップ・MCバトルの専門解説者です。
ラップの技術（ライム、フロー、ダブルミーニング、パンチライン、韻の踏み方など）を
わかりやすく、かつ深く解説します。初心者にもわかるよう丁寧に、
でもマニアックな側面も大切にして説明します。"""

# ---------------------------------------------------------------------------
# ラップ知識Q&A生成（トランスクリプトから抽出）
# ---------------------------------------------------------------------------

RAP_TERMS = {
    "ライム": "rhyme",
    "韻": "rhyme",
    "フロー": "flow",
    "パンチライン": "punchline",
    "ダブルミーニング": "double meaning",
    "多音節韻": "multisyllabic rhyme",
    "内部韻": "internal rhyme",
    "バース": "verse",
    "フック": "hook",
    "16小節": "16 bars",
    "ビート": "beat",
    "サイファー": "cypher",
    "フリースタイル": "freestyle",
    "ディス": "diss",
    "ビーフ": "beef",
    "マルチシラブル": "multisyllabic",
}

QUESTION_TEMPLATES = [
    "「{term}」とはどういう意味ですか？",
    "ラップにおける「{term}」を詳しく解説してください。",
    "「{term}」の使い方と具体例を教えてください。",
    "{term}がうまいラッパーと、その特徴を教えてください。",
    "MCバトルでの「{term}」の重要性について教えてください。",
]

TECHNIQUE_QUESTIONS = [
    ("韻の踏み方にはどんな種類がありますか？",
     "ラップの韻（ライム）には主に以下の種類があります。\n\n"
     "**1. 男性韻（マスキュリン・ライム）**\n最後の1音節だけが一致する基本的な韻。例：「夢（ゆめ）」と「攻め（せめ）」\n\n"
     "**2. 女性韻（フェミニン・ライム）**\n最後の2音節以上が一致する韻。例：「東京（とうきょう）」と「幸福（こうふく）」\n\n"
     "**3. 多音節韻（マルチシラブル）**\n3音節以上の長い韻。エミネムやKendrick Lamarが得意とする技術。\n\n"
     "**4. 内部韻（インターナル・ライム）**\nライン内部でも韻を踏む技術。1行の中に複数の韻が埋め込まれている。\n\n"
     "**5. 音節分割韻**\n複数の単語にまたがって韻を踏む日本語特有の技法。"),

    ("パンチラインとはなんですか？MCバトルでの役割は？",
     "**パンチライン**とは、バース（verse）の中でもっとも印象的で、観客や相手に強いインパクトを与えるラインのことです。\n\n"
     "MCバトルでの役割：\n"
     "- 相手への致命的なdisが含まれることが多い\n"
     "- 客を沸かせる（ウケを取る）決め台詞\n"
     "- 試合の流れを変えるターニングポイントになる\n\n"
     "良いパンチラインの条件：\n"
     "1. **意外性** — 予想外の展開や落ち\n"
     "2. **二重の意味** — ダブルミーニングで聞いた瞬間と後で気づく笑い\n"
     "3. **相手固有の情報** — 相手の名前・外見・経歴をうまく使う\n"
     "4. **リズムと韻** — パンチラインもフローに乗っている"),

    ("フロー（flow）とはラップにおいて何を意味しますか？",
     "**フロー（flow）**はラップにおいて、リズム・テンポ・音節の置き方・休符の使い方などを総合した「ラップのリズムパターン」のことです。\n\n"
     "フローの要素：\n"
     "- **テンポ** — ビートに対してどれだけ速く/遅くラップするか\n"
     "- **シンコペーション** — ビートの裏拍を使って独特のグルーヴを出す\n"
     "- **オフビート** — 意図的にビートから外れることで緊張感を生む\n"
     "- **ブレス（息継ぎ）の位置** — どこで区切るかで意味が変わる\n\n"
     "日本語ラップのフロー特性：\n"
     "日本語は英語より音節が多く（CV構造が基本）、1拍に乗せられる情報量が限られます。\n"
     "そのため日本語ラッパーは音節を連続させる「早口フロー」か、\n"
     "逆に大きな間を活かす「ゆったりフロー」に特化する傾向があります。"),

    ("ダブルミーニング（二重の意味）はどうやって作りますか？",
     "**ダブルミーニング**は、1つのフレーズが同時に2つ（以上）の意味を持つ技法です。\n\n"
     "作り方の種類：\n\n"
     "**1. 同音異義語を使う**\n"
     "例：「花が咲く」= 文字通りの花 / 名声が開花する\n\n"
     "**2. 代名詞の意図的なあいまいさ**\n"
     "「それ」「あいつ」が何を/誰を指しているか複数解釈できるようにする\n\n"
     "**3. 固有名詞の掛け言葉**\n"
     "相手のラッパー名や地名を別の意味にかける（MCバトルで多用）\n\n"
     "**4. 漢字と読みの分離**\n"
     "日本語特有。漢字の意味と読みの音が別々に機能する。\n\n"
     "実例（架空）：「俺のライムは次元が違う」\n"
     "→ 「次元」= 違う次元（レベルが違う）/ アニメキャラ「次元大介」のdis"),

    ("MCバトルで相手を倒すための技術を教えてください。",
     "MCバトルで勝つための主要な技術：\n\n"
     "**1. リサーチとフリップ**\n"
     "相手の弱点・経歴・過去の発言を徹底リサーチし、それをflip（逆手に取る）する。\n\n"
     "**2. パーソナライズ**\n"
     "「どのMCにも言える汎用ライン」ではなく、その相手にしか使えないラインが高評価。\n\n"
     "**3. リアクション力**\n"
     "相手の直前のバースに対してアドリブで返すアドリブ力（特にフリースタイル形式）。\n\n"
     "**4. タイミング**\n"
     "パンチラインをビートの「強拍」に合わせて投下し、最大限のインパクトを出す。\n\n"
     "**5. クラウドコントロール**\n"
     "観客を巻き込む問いかけ、コールアンドレスポンス、間の使い方。\n\n"
     "**6. 積み上げ（ストーリーテリング）**\n"
     "3バース通じてテーマを積み上げ、最後のバースで全部回収する構成力。"),
]


def transcript_to_qa_pairs(record: dict) -> list[dict]:
    """トランスクリプトのセグメントをQAペアに変換"""
    pairs = []
    segments = record.get("segments", [])
    title = record.get("title", "")
    channel = record.get("channel", "")

    if not segments:
        return []

    # 連続するセグメントを結合してパラグラフを作る（最大60秒）
    paragraphs = []
    current_text = []
    current_start = 0.0

    for seg in segments:
        current_text.append(seg["text"])
        if seg["end"] - current_start > 60 or len(" ".join(current_text)) > 500:
            para = " ".join(current_text).strip()
            para = re.sub(r"\s+", " ", para)
            if len(para) > 100:
                paragraphs.append(para)
            current_text = []
            current_start = seg["start"]

    if current_text:
        para = " ".join(current_text).strip()
        if len(para) > 100:
            paragraphs.append(para)

    # パラグラフからQ&Aペアを生成
    for para in paragraphs[:10]:  # 1動画あたり最大10ペア
        # ラップ用語が含まれるパラグラフを優先
        has_term = any(term in para for term in RAP_TERMS)

        if has_term or len(para) > 200:
            # ユーザー質問: この動画（{title}）の内容を要約して解説
            pairs.append({
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": f"「{title}」（{channel}）という動画の以下の部分について、ラップ技術の観点から解説してください：\n\n{para[:400]}"},
                    {"role": "assistant", "content": para},
                ]
            })

    return pairs


def build_curated_pairs() -> list[dict]:
    """厳選した専門知識Q&Aペア（手動作成）"""
    pairs = []

    # 技術Q&A
    for question, answer in TECHNIQUE_QUESTIONS:
        pairs.append({
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": question},
                {"role": "assistant", "content": answer},
            ]
        })

    # 用語解説
    term_answers = {
        "ライム": "**ライム（韻・rhyme）**とはラップにおいて、音の響きが似ている単語や音節を意図的に組み合わせる技術です。日本語では「韻を踏む」と言います。\n\nラップにおけるライムは単なる「言葉遊び」ではなく、フローのリズムを強化し、聴衆の記憶に残りやすくする重要な技術です。英語では末尾音の一致が基本ですが、日本語では母音の一致（例：「東京」と「望郷」どちらも「おうきょう」という母音列）が主流です。",

        "フリースタイル": "**フリースタイル（freestyle）**は、事前に歌詞を書かずにその場でリアルタイムに即興でラップする技術・スタイルです。\n\nフリースタイルの種類：\n- **バトルフリースタイル** — 相手を口撃する即興バトル\n- **サイファーフリースタイル** — 輪になって順番にラップを回す\n- **ビートジャック** — かかっている曲に即興で乗る\n\n日本では「高校生RAP選手権」や「フリースタイルダンジョン」でフリースタイルバトルが広まりました。",

        "サイファー": "**サイファー（cypher）**はヒップホップ文化における輪になって即興でラップを回す行為、またはその形式のことです。\n\nBET Hip Hop Awardsのサイファーは世界的に有名で、トップラッパーが集まりアカペラまたは1ビートの上で順番にバースをラップします。Kendrick Lamarが2013年のBETサイファーで披露したバースは「Control」として独立リリースされ、歴史的名盤となりました。\n\n日本語ラップシーンでもサイファーは重要な文化で、MCの実力を試す場として機能しています。",
    }

    for term, answer in term_answers.items():
        for template in random.sample(QUESTION_TEMPLATES, 2):
            q = template.format(term=term)
            pairs.append({
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": q},
                    {"role": "assistant", "content": answer},
                ]
            })

    return pairs


def prepare():
    print(f"\n{'='*60}")
    print("Fine-tuningデータ準備")
    print(f"{'='*60}\n")

    all_pairs = []

    # 1. 厳選Q&Aペア（ベース知識）
    curated = build_curated_pairs()
    all_pairs.extend(curated)
    print(f"厳選Q&Aペア: {len(curated)} 件")

    # 2. YouTubeトランスクリプトから生成
    transcript_files = list(TRANSCRIPT_DIR.glob("*.json"))
    print(f"トランスクリプトファイル: {len(transcript_files)} 件")

    yt_pairs = []
    for f in transcript_files:
        try:
            record = json.loads(f.read_text())
            pairs = transcript_to_qa_pairs(record)
            yt_pairs.extend(pairs)
        except Exception as e:
            print(f"  ⚠ {f.name}: {e}")

    all_pairs.extend(yt_pairs)
    print(f"YouTubeベースQ&A: {len(yt_pairs)} 件")

    # シャッフル
    random.shuffle(all_pairs)

    # 最低ライン確認（OpenAIは10件以上必要）
    if len(all_pairs) < 10:
        print(f"\n⚠ データが少なすぎます（{len(all_pairs)}件）。collect_training_data.py を先に実行してください。")
        print("  現在の厳選データのみで出力します。")

    # train / validation 分割（9:1）
    split = max(1, int(len(all_pairs) * 0.9))
    train_data = all_pairs[:split]
    val_data = all_pairs[split:]

    # 保存
    train_path = OUTPUT_DIR / "finetune_rap_explain_train.jsonl"
    val_path = OUTPUT_DIR / "finetune_rap_explain_val.jsonl"

    train_path.write_text("\n".join(json.dumps(p, ensure_ascii=False) for p in train_data))
    val_path.write_text("\n".join(json.dumps(p, ensure_ascii=False) for p in val_data))

    print(f"\n✅ 学習データ: {len(train_data)} 件 → {train_path}")
    print(f"✅ 検証データ: {len(val_data)} 件 → {val_path}")
    print(f"\n次のステップ: python finetune.py")


if __name__ == "__main__":
    prepare()
