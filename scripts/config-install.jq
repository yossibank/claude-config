def claude_config_hook: (.command // "") | (contains("claude-config/hooks/") or contains("/.claude/hooks/run.sh"));

.[0] as $current
| .[1] as $config
| (.[2] // []) as $installed
| ($current.permissions.allow // []) as $allow
| ($allow - ($installed - $config.permissions.allow)) as $kept
| $current
| .permissions.allow = $kept + ($config.permissions.allow - $kept)
| .hooks = (
    reduce ($config.hooks | keys_unsorted[]) as $event (
        ($current.hooks // {})
        | map_values(map(.hooks |= map(select(claude_config_hook | not)) | select(.hooks | length > 0)));
        .[$event] = ((.[$event] // []) + $config.hooks[$event])
    )
    | with_entries(select(.value | length > 0))
)
| if $config.outputStyle and $current.outputStyle == null then .outputStyle = $config.outputStyle else . end
