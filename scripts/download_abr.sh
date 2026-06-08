#!/bin/bash
# shellcheck shell=bash
# ABR (アドレス・ベース・レジストリ) からテストデータを取得
#
# DCAT feed (https://dataset.address-br.digital.go.jp/api/feed/dcat-us/1.1.json) を経由して
# 都道府県別/市区町村別 CSV をダウンロードし、DuckDB で結合して住所を抽出する。
#
# 環境変数:
#   PREF            - 都道府県コード(2桁、例 13)を指定すると当該都道府県のみ取得 (デフォルト: 全47)
#   SKIP_RSDTDSP=1  - 住居表示マスター (rsdtdsp_blk + rsdtdsp_rsdt) をスキップ
#   SKIP_PARCEL=1   - 地番マスター (約 1900 ファイル / 数GB) をスキップ
#
# 出力:
#   data/raw/abr/{mt_city,mt_town_fullset,mt_rsdtdsp_blk,mt_rsdtdsp_rsdt,mt_parcel}/*.csv
#   data/prc/abr_{pref,city,town,blk,rsdt,parcel}.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
init_dirs "$SCRIPT_DIR"

# abr は raw 配下にサブディレクトリを掘る
RAW_DIR="$RAW_DIR/abr"
mkdir -p "$RAW_DIR"

FEED_URL="https://dataset.address-br.digital.go.jp/api/feed/dcat-us/1.1.json"
FEED_FILE="$RAW_DIR/feed.json"
PARALLEL=${PARALLEL:-16}

require_command curl jq unzip duckdb

# DCAT feed (キャッシュ)
if [ ! -f "$FEED_FILE" ]; then
    log_info "[abr] DCAT feed 取得..."
    curl -fsSL "$FEED_URL" -o "$FEED_FILE"
fi
log_info "[abr] DCAT feed: $(wc -c < "$FEED_FILE") bytes"

extract_urls() {
    # $1: path pattern (例 "mt_city/pref")
    local pattern=$1
    local pref_filter=""
    if [ -n "${PREF:-}" ]; then
        # PREF=13 なら _pref13 や _cityNN (NN の先頭2桁が 13) を含む URL のみ
        pref_filter='| select(test("pref'"$PREF"'\\.csv\\.zip$") or test("city'"$PREF"'[0-9]{4}\\.csv\\.zip$"))'
    fi
    jq -r --arg p "$pattern" '
        .dataset[].distribution[]?.accessURL // empty
        | select(test("/" + $p + "/[^/]+\\.csv\\.zip$"))
        '"$pref_filter"'
    ' "$FEED_FILE" | sort -u
}

download_zip() {
    # $1: URL, $2: 出力ディレクトリ
    local url=$1
    local out_dir=$2
    local zip_name="${url##*/}"
    local csv_name="${zip_name%.zip}"
    local out_csv="$out_dir/$csv_name"

    if [ -f "$out_csv" ]; then return 0; fi

    local tmp_zip
    tmp_zip=$(mktemp -t abr_XXXXXX.zip)
    if ! curl -fsSL --max-time 120 "$url" -o "$tmp_zip"; then
        echo "[WARN] download failed: $url" >&2
        rm -f "$tmp_zip"
        return 1
    fi
    unzip -p "$tmp_zip" > "$out_csv"
    rm -f "$tmp_zip"
}
export -f download_zip

fetch_category() {
    # $1: path pattern, $2: 出力サブディレクトリ名
    local pattern=$1
    local subdir=$2
    local out_dir="$RAW_DIR/$subdir"
    mkdir -p "$out_dir"

    local urls_file
    urls_file=$(mktemp -t abr_urls_XXXXXX)
    extract_urls "$pattern" > "$urls_file"
    local n
    n=$(wc -l < "$urls_file")
    log_info "  $subdir: $n ファイルをダウンロード (並列 $PARALLEL)..."
    xargs -a "$urls_file" -P "$PARALLEL" -I{} bash -c 'download_zip "$@"' _ {} "$out_dir"
    rm -f "$urls_file"
    log_info "  $subdir: 完了 ($(find "$out_dir" -name '*.csv' | wc -l) ファイル)"
}

log_info "[abr] CSV ダウンロード"
fetch_category "mt_city/pref"            "mt_city"
fetch_category "mt_town_fullset/pref"    "mt_town_fullset"

if [ "${SKIP_RSDTDSP:-0}" = "1" ]; then
    log_info "  mt_rsdtdsp_blk: スキップ (SKIP_RSDTDSP=1)"
    log_info "  mt_rsdtdsp_rsdt: スキップ (SKIP_RSDTDSP=1)"
else
    fetch_category "mt_rsdtdsp_blk/pref"     "mt_rsdtdsp_blk"
    fetch_category "mt_rsdtdsp_rsdt/pref"    "mt_rsdtdsp_rsdt"
fi

if [ "${SKIP_PARCEL:-0}" = "1" ]; then
    log_info "  mt_parcel: スキップ (SKIP_PARCEL=1)"
else
    fetch_category "mt_parcel/city" "mt_parcel"
fi

log_info "[abr] DuckDB で住所抽出"

# union_by_name=true で都道府県ごとのスキーマ差異を吸収
# all_varchar=true で型推測のブレ (例: blk_num に「南2」など) を回避
opts='union_by_name=true, all_varchar=true'
read_city="read_csv_auto('$RAW_DIR/mt_city/*.csv', $opts)"
read_town="read_csv_auto('$RAW_DIR/mt_town_fullset/*.csv', $opts)"
read_blk="read_csv_auto('$RAW_DIR/mt_rsdtdsp_blk/*.csv', $opts)"
read_rsdt="read_csv_auto('$RAW_DIR/mt_rsdtdsp_rsdt/*.csv', $opts)"
read_parcel="read_csv_auto('$RAW_DIR/mt_parcel/*.csv', $opts)"

emit_abr() {
    local name=$1
    local sql=$2
    log_info "  prc/abr_${name}.txt 生成..."
    duckdb -noheader -list -c "$sql" > "$PRC_DIR/abr_${name}.txt"
    log_info "    -> $(wc -l < "$PRC_DIR/abr_${name}.txt") 件"
}

emit_abr "pref" "
COPY (
  SELECT DISTINCT pref AS addr
  FROM $read_city
  WHERE pref IS NOT NULL
  ORDER BY 1
) TO STDOUT (HEADER false);
"

emit_abr "city" "
COPY (
  SELECT DISTINCT pref || COALESCE(county, '') || city || COALESCE(ward, '') AS addr
  FROM $read_city
  ORDER BY 1
) TO STDOUT (HEADER false);
"

emit_abr "town" "
COPY (
  SELECT DISTINCT
    c.pref || COALESCE(c.county, '') || c.city || COALESCE(c.ward, '')
    || COALESCE(t.oaza_cho, '') || COALESCE(t.chome, '') || COALESCE(t.koaza, '') AS addr
  FROM $read_town t
  JOIN $read_city c ON t.lg_code = c.lg_code
  ORDER BY 1
) TO STDOUT (HEADER false);
"

if [ "${SKIP_RSDTDSP:-0}" != "1" ]; then
    emit_abr "blk" "
COPY (
  SELECT DISTINCT
    c.pref || COALESCE(c.county, '') || c.city || COALESCE(c.ward, '')
    || COALESCE(t.oaza_cho, '') || COALESCE(t.chome, '') || COALESCE(t.koaza, '')
    || b.blk_num || '番' AS addr
  FROM $read_blk b
  JOIN $read_town t ON b.lg_code = t.lg_code AND b.machiaza_id = t.machiaza_id
  JOIN $read_city c ON b.lg_code = c.lg_code
  WHERE b.blk_num IS NOT NULL
  ORDER BY 1
) TO STDOUT (HEADER false);
"

    emit_abr "rsdt" "
COPY (
  SELECT DISTINCT
    c.pref || COALESCE(c.county, '') || c.city || COALESCE(c.ward, '')
    || COALESCE(t.oaza_cho, '') || COALESCE(t.chome, '') || COALESCE(t.koaza, '')
    || r.blk_num || '番' || r.rsdt_num
    || COALESCE('-' || r.rsdt_num2, '')
    || '号' AS addr
  FROM $read_rsdt r
  JOIN $read_town t ON r.lg_code = t.lg_code AND r.machiaza_id = t.machiaza_id
  JOIN $read_city c ON r.lg_code = c.lg_code
  WHERE r.blk_num IS NOT NULL AND r.rsdt_num IS NOT NULL
  ORDER BY 1
) TO STDOUT (HEADER false);
"
fi

if [ "${SKIP_PARCEL:-0}" != "1" ]; then
    emit_abr "parcel" "
COPY (
  SELECT DISTINCT
    c.pref || COALESCE(c.county, '') || c.city || COALESCE(c.ward, '')
    || COALESCE(t.oaza_cho, '') || COALESCE(t.chome, '') || COALESCE(t.koaza, '')
    || p.prc_num1 || '番地'
    || COALESCE(p.prc_num2, '')
    || COALESCE('-' || p.prc_num3, '') AS addr
  FROM $read_parcel p
  JOIN $read_town t ON p.lg_code = t.lg_code AND p.machiaza_id = t.machiaza_id
  JOIN $read_city c ON p.lg_code = c.lg_code
  WHERE p.prc_num1 IS NOT NULL
  ORDER BY 1
) TO STDOUT (HEADER false);
"
fi

log_info "[abr] 完了"
