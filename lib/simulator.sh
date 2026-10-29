pick_iphone() {
    if [[ -n ${CC_UI_DEVICE:-} ]]; then
        echo "$CC_UI_DEVICE"
        return
    fi
    xcrun simctl list devices available -j | jq -r '[.devices[][] | select(.name | startswith("iPhone")) | .udid][0] // empty'
}
