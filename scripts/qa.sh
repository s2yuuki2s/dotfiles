#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

info() { echo "[INFO] $1"; }
error() { echo "[ERROR] $1" >&2; exit 1; }

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || error "Missing required command: $cmd"
}

collect_shell_files() {
    git -C "$ROOT_DIR" ls-files "*.sh"
}

run_bash_parse_check() {
    info "Running bash parser checks..."
    local file
    while IFS= read -r file; do
        bash -n "$ROOT_DIR/$file"
    done < <(collect_shell_files)
}

run_shellcheck() {
    info "Running shellcheck..."
    require_cmd shellcheck

    mapfile -t files < <(collect_shell_files)
    local abs=()
    local file
    for file in "${files[@]}"; do
        abs+=("$ROOT_DIR/$file")
    done
    shellcheck --severity=warning "${abs[@]}"
}

run_shfmt_fix() {
    info "Formatting shell scripts with shfmt..."
    require_cmd shfmt

    mapfile -t files < <(collect_shell_files)
    local abs=()
    local file
    for file in "${files[@]}"; do
        abs+=("$ROOT_DIR/$file")
    done
    shfmt -w -i 4 -ci "${abs[@]}"
}

usage() {
    cat <<'EOF'
Usage: ./scripts/qa.sh <check|fix>

  check  Run parser checks + shellcheck + module registry checks
  fix    Run shfmt, then run all checks
EOF
}

main() {
    local mode="${1:-check}"

    case "$mode" in
        check)
            run_bash_parse_check
            run_shellcheck
            info "QA checks passed."
            ;;
        fix)
            run_shfmt_fix
            run_bash_parse_check
            run_shellcheck
            info "Formatting and QA checks passed."
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
