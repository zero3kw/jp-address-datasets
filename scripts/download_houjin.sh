#!/bin/bash
# shellcheck shell=bash
# 法人番号データ (国税庁 法人番号公表サイト)
#
# セッションクッキー + CSRF トークン + POST で全件 ZIP を自動取得し、
# Shift-JIS から UTF-8 に変換、住所列を抽出して重複排除する。
#
# 出力:
#   data/raw/houjin.csv     (UTF-8 変換済み、約 1.2GB)
#   data/prc/houjin.txt     (住所重複排除、約 250MB / 約 445 万件)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
init_dirs "$SCRIPT_DIR"

require_command curl unzip iconv

fetch_houjin_zip() {
    # 標準出力に取得した ZIP のパスを出力する
    local ua="Mozilla/5.0 (jp-address-datasets)"
    local base_url="https://www.houjin-bangou.nta.go.jp/download/zenken/"
    local cookies page out_zip
    cookies=$(mktemp -t houjin_cookies.XXXXXX)
    page=$(mktemp -t houjin_page.XXXXXX.html)
    out_zip=$(mktemp -t houjin.XXXXXX.zip)

    log_info "  ダウンロードページから token/fileno を取得..." >&2
    curl -fsSL -A "$ua" -c "$cookies" "$base_url" -o "$page"

    local token fileno
    token=$(grep -oE 'name="jp\.go\.nta[^"]*token" value="[^"]*"' "$page" \
            | sed -E 's/.*value="([^"]*)"/\1/' | head -1)
    # CSV Shift-JIS 全国 = ページ先頭の doDownload
    fileno=$(grep -oE 'doDownload\([0-9]+\)' "$page" | head -1 | grep -oE '[0-9]+')

    if [ -z "$token" ] || [ -z "$fileno" ]; then
        log_error "token/fileno の抽出に失敗 (token='$token' fileno='$fileno')"
        rm -f "$cookies" "$page"
        return 1
    fi
    log_info "  fileno=$fileno を POST で取得..." >&2

    curl -fsSL -A "$ua" -b "$cookies" -c "$cookies" \
        -d "event=download" \
        -d "selDlFileNo=$fileno" \
        --data-urlencode "jp.go.nta.houjin_bangou.framework.web.common.CNSFWTokenProcessor.request.token=$token" \
        -o "$out_zip" \
        "${base_url}index.html"

    rm -f "$cookies" "$page"

    # ZIP magic (PK\x03\x04) を確認
    if ! head -c 4 "$out_zip" | od -An -c | grep -q 'P   K'; then
        log_error "応答が ZIP ではありません: $out_zip"
        rm -f "$out_zip"
        return 1
    fi

    echo "$out_zip"
}

log_info "[houjin] 法人番号データ"

if [ ! -f "$RAW_DIR/houjin.csv" ]; then
    log_info "  法人番号公表サイトから自動取得します"
    if ! zip_file=$(fetch_houjin_zip); then
        log_error "自動取得に失敗しました"
        exit 1
    fi

    log_info "  ZIP: $zip_file を解凍中..."
    tmp_csv=$(mktemp -t houjin_csv.XXXXXX)
    unzip -p "$zip_file" '00_zenkoku_all_*.csv' > "$tmp_csv"

    log_info "  エンコーディング検出..."
    if head -c 1000 "$tmp_csv" | grep -q '北海道\|東京都\|大阪府'; then
        log_info "  -> UTF-8 として保存"
        mv "$tmp_csv" "$RAW_DIR/houjin.csv"
    else
        log_info "  -> Shift-JIS -> UTF-8 変換"
        iconv -f SHIFT_JIS -t UTF-8 "$tmp_csv" > "$RAW_DIR/houjin.csv"
        rm -f "$tmp_csv"
    fi
    rm -f "$zip_file"
    log_info "  -> raw/houjin.csv 作成完了"
else
    log_info "  -> raw/houjin.csv 既存 (スキップ)"
fi

log_info "  住所抽出中 (列10-12 を結合・重複排除)..."
# LC_ALL=C で高速ソート
cut -d',' -f10,11,12 "$RAW_DIR/houjin.csv" | tr -d '"' | sed 's/,//g' \
    | LC_ALL=C sort -u > "$PRC_DIR/houjin.txt"
log_info "  -> prc/houjin.txt 作成 ($(wc -l < "$PRC_DIR/houjin.txt") 件)"
