#!/usr/bin/env bash
set -euo pipefail

[[ -z "${DOTFILES_DIR:-}" ]] && DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/utils.sh
source "$DOTFILES_DIR/lib/utils.sh"

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || error "Missing required command: $cmd"
}

collect_shell_files() {
    git -C "$DOTFILES_DIR" ls-files "*.sh"
}

run_bash_parse_check() {
    info "== Running Bash Parser Checks =="
    local file
    while IFS= read -r file; do
        bash -n "$DOTFILES_DIR/$file"
    done < <(collect_shell_files)
}

run_shellcheck() {
    info "== Running ShellCheck =="
    require_cmd shellcheck

    mapfile -t files < <(collect_shell_files)
    local abs=()
    local file
    for file in "${files[@]}"; do
        abs+=("$DOTFILES_DIR/$file")
    done
    shellcheck --severity=warning "${abs[@]}"
}

run_shfmt_fix() {
    info "== Formatting Shell Scripts =="
    require_cmd shfmt

    mapfile -t files < <(collect_shell_files)
    local abs=()
    local file
    for file in "${files[@]}"; do
        abs+=("$DOTFILES_DIR/$file")
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
            info "✅ QA checks passed."
            ;;
        fix)
            run_shfmt_fix
            run_bash_parse_check
            run_shellcheck
            info "✅ Formatting and QA checks passed."
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
