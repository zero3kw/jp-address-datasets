#!/bin/bash
# shellcheck shell=bash
# データセット取得 dispatcher
#
# 各データセットは scripts/download_{dataset}.sh に分離されている。
# このスクリプトは引数で指定された対象を呼び出すだけ。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
    cat <<EOF
Usage: $0 [dataset]

Datasets:
  all        - 全データセット (デフォルト)
  jat        - Japanese Address Testdata (t-sagara)
  nja        - Normalize Japanese Addresses (geolonia)
  nta-houjin - 法人番号データ (国税庁)
  school     - 国土数値情報 学校データ (国交省)
  abr        - ABRデータ (デジタル庁)

各データセットで以下のファイルを生成します:
  data/raw/{dataset}.{ext}  取得元データ
  data/prc/{dataset}.txt    住所のみを抽出したファイル
EOF
    exit 1
}

run() {
    bash "$SCRIPT_DIR/download_$1.sh"
}

DATASET="${1:-all}"

case "$DATASET" in
    all)
        run jat
        echo ""
        run nja
        echo ""
        run nta-houjin || true   # 自動取得失敗時も他データセットを続行
        echo ""
        run school
        echo ""
        run abr || true
        ;;
    jat|nja|nta-houjin|school|abr) run "$DATASET" ;;
    *)
        log_error "Unknown dataset '$DATASET'"
        usage
        ;;
esac

echo ""
log_info "=== 完了 ==="
log_info "ファイル一覧:"
shopt -s nullglob
DATA_DIR="$SCRIPT_DIR/../data"
DATA_FILES=("$DATA_DIR/raw"/* "$DATA_DIR/prc"/*)
shopt -u nullglob
if [[ ${#DATA_FILES[@]} -gt 0 ]]; then
    ls -lh "${DATA_FILES[@]}"
else
    log_info "  (ファイルなし)"
fi
