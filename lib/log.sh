show_errors() {
    { grep -E 'error:|[Ff]ailed|^NG |\*\*\*' "$1" || true; } | awk '!seen[$0]++' | tail -n "${2:-20}"
}
