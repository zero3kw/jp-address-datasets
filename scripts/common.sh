#!/bin/bash
# shellcheck shell=bash
# 共通関数とディレクトリ初期化

log_info()  { echo "[INFO] $*"; }
log_warn()  { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

require_command() {
    local missing=0
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "$cmd command not found in PATH"
            missing=1
        fi
    done
    return $missing
}

# 各 download_*.sh から source されたあと呼び出す。
# DATA_DIR / RAW_DIR / PRC_DIR を export する。
init_dirs() {
    local script_dir=$1
    mkdir -p "$script_dir/../data/raw" "$script_dir/../data/prc"
    DATA_DIR="$(cd "$script_dir/../data" && pwd)"
    RAW_DIR="$DATA_DIR/raw"
    PRC_DIR="$DATA_DIR/prc"
    export DATA_DIR RAW_DIR PRC_DIR
}
