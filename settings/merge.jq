def ours: (.command // "") | contains("claude-config/hooks/");

.[0] as $current
| .[1] as $config
| ($current.permissions.allow // []) as $allow
| $current
| .permissions.allow = $allow + ($config.permissions.allow - $allow)
| .hooks = (
    reduce ($config.hooks | keys_unsorted[]) as $event (
        ($current.hooks // {})
        | map_values(map(.hooks |= map(select(ours | not)) | select(.hooks | length > 0)));
        .[$event] = ((.[$event] // []) + $config.hooks[$event])
    )
    | with_entries(select(.value | length > 0))
)
