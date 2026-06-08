#!/bin/bash
# shellcheck shell=bash
# Japanese Address Testdata (t-sagara)
#
# 出力:
#   data/raw/jat.csv
#   data/prc/jat.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
init_dirs "$SCRIPT_DIR"

require_command curl

log_info "[jat] Japanese Address Testdata (t-sagara)"
if [ ! -f "$RAW_DIR/jat.csv" ]; then
    log_info "  raw データ取得中..."
    curl -fsSL "https://raw.githubusercontent.com/t-sagara/Japanese-Address-testdata/main/simple.csv" \
        -o "$RAW_DIR/jat.csv"
    log_info "  -> raw/jat.csv 取得完了"
else
    log_info "  -> raw/jat.csv 既存 (スキップ)"
fi
log_info "  住所抽出中..."
tail -n +2 "$RAW_DIR/jat.csv" | cut -d',' -f1 | LC_ALL=C sort -u > "$PRC_DIR/jat.txt"
log_info "  -> prc/jat.txt 作成 ($(wc -l < "$PRC_DIR/jat.txt") 件)"
