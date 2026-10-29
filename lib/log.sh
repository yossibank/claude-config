show_errors() {
    local cut=tail
    [[ ${2:-} == first ]] && cut=head
    { grep -E -i 'error:|fail|^NG ' "$1" || true; } | awk '!seen[$0]++' | "$cut" -n 20
}
