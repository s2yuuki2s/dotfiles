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

collect_install_scripts() {
    (
        cd "$ROOT_DIR/installs"
        find . -maxdepth 1 -type f -name "*.sh" -printf "%f\n" | sort
    )
}

collect_setup_modules() {
    sed -n '/^scripts=(/,/)/p' "$ROOT_DIR/setup.sh" \
        | sed -n 's/^[[:space:]]*"\([^"]\+\.sh\)".*/\1/p' \
        | sort
}

check_setup_module_registry() {
    local install_list
    local setup_list
    install_list=$(collect_install_scripts)
    setup_list=$(collect_setup_modules)

    local missing_in_setup
    local missing_in_installs
    missing_in_setup=$(comm -23 <(printf "%s\n" "$install_list") <(printf "%s\n" "$setup_list") || true)
    missing_in_installs=$(comm -13 <(printf "%s\n" "$install_list") <(printf "%s\n" "$setup_list") || true)

    if [[ -n "$missing_in_setup" ]]; then
        error "setup.sh is missing modules for: $missing_in_setup"
    fi
    if [[ -n "$missing_in_installs" ]]; then
        error "setup.sh references missing install scripts: $missing_in_installs"
    fi
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
            check_setup_module_registry
            run_shellcheck
            info "QA checks passed."
            ;;
        fix)
            run_shfmt_fix
            run_bash_parse_check
            check_setup_module_registry
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
