#!/bin/bash
# shellcheck shell=bash
# 国土数値情報 学校等 (P29-21)
#
# 出力:
#   data/raw/school.geojson
#   data/prc/school.txt   (幼稚園・小中高・大学・専修学校等を含む全種別)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
init_dirs "$SCRIPT_DIR"

require_command curl unzip duckdb

log_info "[school] 国土数値情報 学校 (P29-21)"
if [ ! -f "$RAW_DIR/school.geojson" ]; then
    log_info "  raw データ取得中..."
    zip_path="$DATA_DIR/P29-21_GML.zip"
    tmp_dir="$DATA_DIR/.school_tmp"
    curl -fsSL "https://nlftp.mlit.go.jp/ksj/gml/data/P29/P29-21/P29-21_GML.zip" \
        -o "$zip_path"
    log_info "  解凍中..."
    unzip -q -o "$zip_path" -d "$tmp_dir"
    geojson_file=$(find "$tmp_dir" -name "*.geojson" -type f | head -1)
    if [[ -z "$geojson_file" ]]; then
        log_error "GeoJSON ファイルが見つかりません"
        rm -rf "$tmp_dir" "$zip_path"
        exit 1
    fi
    mv "$geojson_file" "$RAW_DIR/school.geojson"
    rm -rf "$tmp_dir" "$zip_path"
    log_info "  -> raw/school.geojson 作成完了"
else
    log_info "  -> raw/school.geojson 既存 (スキップ)"
fi

log_info "  住所抽出中 (全種別: 幼稚園・小中高・大学・専修学校等)..."
duckdb -noheader -list -c "
    SELECT DISTINCT f.properties.P29_005
    FROM read_json('$RAW_DIR/school.geojson', maximum_object_size=200000000),
         UNNEST(features) as t(f)
    WHERE f.properties.P29_005 IS NOT NULL
      AND f.properties.P29_005 != ''
    ORDER BY 1
" > "$PRC_DIR/school.txt"
log_info "  -> prc/school.txt 作成 ($(wc -l < "$PRC_DIR/school.txt") 件)"
