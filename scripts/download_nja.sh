#!/bin/bash
# shellcheck shell=bash
# Normalize Japanese Addresses test corpus (geolonia)
#
# 出力:
#   data/raw/nja.csv
#   data/prc/nja.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
init_dirs "$SCRIPT_DIR"

require_command curl

log_info "[nja] Normalize Japanese Addresses (geolonia)"
if [ ! -f "$RAW_DIR/nja.csv" ]; then
    log_info "  raw データ取得中..."
    curl -fsSL "https://raw.githubusercontent.com/geolonia/normalize-japanese-addresses/master/test/addresses/addresses.csv" \
        -o "$RAW_DIR/nja.csv"
    log_info "  -> raw/nja.csv 取得完了"
else
    log_info "  -> raw/nja.csv 既存 (スキップ)"
fi
log_info "  住所抽出中..."
tail -n +2 "$RAW_DIR/nja.csv" | cut -d',' -f1 | LC_ALL=C sort -u > "$PRC_DIR/nja.txt"
log_info "  -> prc/nja.txt 作成 ($(wc -l < "$PRC_DIR/nja.txt") 件)"
