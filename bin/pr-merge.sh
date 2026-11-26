#!/bin/bash
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
source "$here/../lib/git.sh"
source "$here/../lib/build_log.sh"

label=com.claude-config.pr-merge
stop_label=auto-merge-stopped
state="$HOME/.claude/state/pr-merge"
claude_tools=(Read Edit Write Grep Glob "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)" "Bash(git status:*)")

usage() {
    echo "NG 使い方: pr-merge.sh run|install <リポジトリ>..."
    exit 1
}

notify() {
    terminal-notifier -title "$1" -subtitle "$2" -message "$3" -open "$4" -group "pr-merge-$2" -sound default >/dev/null 2>&1 || true
}

mergeable_of() {
    local value tries=0
    while :; do
        value=$(gh pr view "$1" --repo "$slug" --json mergeable -q .mergeable) || value=UNKNOWN
        [[ $value != UNKNOWN && -n $value ]] && break
        tries=$((tries + 1))
        [[ $tries -lt 6 ]] || break
        sleep 10
    done
    echo "${value:-UNKNOWN}"
}

merge_pr() {
    gh pr merge "$1" --repo "$slug" --squash >/dev/null 2>&1 || return 1
    [[ -f $state/$key ]] || return 0
    rm -f "$state/$key"
    gh pr edit "$1" --repo "$slug" --remove-label "$stop_label" >/dev/null 2>&1 || true
}

stop_pr() {
    local reason=$1 details=${2:-}
    echo "$oid $base_oid" >"$state/$key"
    echo "NG $slug#$number $reason"
    gh label create "$stop_label" --repo "$slug" --color B60205 --description "自動マージを止めた PR" --force >/dev/null 2>&1 || true
    gh pr edit "$number" --repo "$slug" --add-label "$stop_label" >/dev/null 2>&1 || true
    gh pr comment "$number" --repo "$slug" --body "$(printf '自動マージを止めました。\n\n| 項目 | 中身 |\n| --- | --- |\n| 理由 | %s |\n| ワークツリー | `%s` |\n\n```\n%s\n```\n' "$reason" "$wt" "${details:-（詳しい行は無い）}")" >/dev/null 2>&1 || true
    notify "自動マージを止めました" "$name#$number" "${reason}。クリックで PR を開きます" "$url"
}

ask_claude() {
    local out last
    out=$(cd "$wt" && claude -p "$1" --permission-mode acceptEdits --allowedTools "${claude_tools[@]}" 2>&1) || true
    echo "$out" >>"$log"
    last=$(printf '%s\n' "$out" | awk 'NF {line = $0} END {print line}')
    [[ $last == OK* ]] || {
        claude_reason=${last#NG }
        return 1
    }
}

conflicted_files() {
    git -C "$wt" diff --name-only --diff-filter=U
}

has_markers() {
    local file
    while IFS= read -r file; do
        grep -qE '^(<<<<<<<|>>>>>>>)( |$)' "$wt/$file" 2>/dev/null && return 0
    done <<<"$1"
    return 1
}

run_checks() {
    (cd "$wt" && make verify) >"$log.checks" 2>&1 || return 1
    if grep -qE '^test:' "$wt/Makefile" && ! grep -qE '^verify:(.* )?test( |$)' "$wt/Makefile"; then
        (cd "$wt" && make test) >>"$log.checks" 2>&1 || return 1
    fi
}

prepare_worktree() {
    if [[ ! -d $wt ]]; then
        git -C "$repo" worktree add -q --detach "$wt" "$oid"
        return
    fi
    git -C "$wt" rebase --abort >/dev/null 2>&1 || true
    git -C "$wt" checkout -q --force --detach "$oid" || return 1
    git -C "$wt" clean -qfd
}

rebase_pr() {
    local status=0 files rounds=0 file
    git -C "$wt" rebase -q "$base" >>"$log" 2>&1 || status=$?
    while [[ $status != 0 ]]; do
        files=$(conflicted_files)
        rounds=$((rounds + 1))
        if [[ -z $files || $rounds -gt 20 ]]; then
            claude_reason="載せ直しが競合の外で止まった"
            return 1
        fi
        ask_claude "PR #${number}「${title}」のブランチを $base に載せ直していて、次のファイルが競合した。

$files

- 印（<<<<<<<・=======・>>>>>>>）の両側と、git log・git show で両方の変更の意図を確かめ、両方の意図が残る形に書き直す。$base 側で入った変更を消さない。
- 印を残さない。競合したファイルの外は変えない。git の add・commit・rebase はしない。
- 両方の意図を残す形が決まらない時は、ファイルを変えずに終える。
- 最後の行は、解けたら OK、解けなかったら「NG <理由>」にする。" || return 1
        if has_markers "$files"; then
            claude_reason="競合の印が残った"
            return 1
        fi
        while IFS= read -r file; do git -C "$wt" add -- "$file"; done <<<"$files"
        status=0
        GIT_EDITOR=true git -C "$wt" rebase --continue >>"$log" 2>&1 || status=$?
    done
}

untracked_files() {
    git -C "$wt" ls-files --others --exclude-standard
}

check_pr() {
    local before file
    run_checks && return 0
    before=$(untracked_files)
    ask_claude "PR #${number}「${title}」を $base に載せ直して競合を解いた後、確認が落ちた。落ちた行は次のとおり。

$(show_errors "$log.checks")

- 競合を解いた所が原因の所だけを直す。PR の狙いを変えない。
- git の add・commit はしない。
- 最後の行は、直したら OK、直せなかったら「NG <理由>」にする。" || return 1
    [[ -n $(git -C "$wt" status --porcelain) ]] || return 1
    git -C "$wt" add -u
    while IFS= read -r file; do
        [[ -n $file ]] && git -C "$wt" add -- "$file"
    done < <(comm -13 <(printf '%s\n' "$before" | sort) <(untracked_files | sort))
    git -C "$wt" commit -q -m "fix: keep the checks passing after the rebase onto ${base#origin/}"
    run_checks
}

resolve_pr() {
    claude_reason=""
    if pgrep -qx xcodebuild; then
        echo "SKIP $slug#$number xcodebuild が動いているので、次の回に回す" >&2
        return 0
    fi
    if ! prepare_worktree >>"$log" 2>&1; then
        echo "NG $slug#$number ワークツリーを用意できなかった"
        return 0
    fi
    if ! rebase_pr; then
        git -C "$wt" rebase --abort >/dev/null 2>&1 || true
        stop_pr "競合を解けませんでした（${claude_reason:-理由の行が無い}）" "$(conflicted_files)"
        return 0
    fi
    if ! check_pr; then
        stop_pr "競合を解いた後の確認が落ちました" "$(show_errors "$log.checks")"
        return 0
    fi
    if ! git -C "$wt" push -q --force-with-lease="$head:$oid" origin "HEAD:refs/heads/$head" >>"$log" 2>&1; then
        stop_pr "PR のブランチに push できませんでした" "$(tail -5 "$log")"
        return 0
    fi
    if [[ $(mergeable_of "$number") == MERGEABLE ]] && merge_pr "$number"; then
        echo "OK $slug#$number 競合を解いてマージした"
        notify "競合を解いてマージしました" "$name#$number" "確認は通りました。解いた所はクリックで PR から見られます" "$url"
    else
        stop_pr "競合を解いて push しましたが、マージできませんでした"
    fi
}

handle_pr() {
    key="${slug//\//_}-$number"
    log="$state/$key.log"
    : >"$log"
    if merge_pr "$number"; then
        echo "OK $slug#$number マージした"
        return 0
    fi
    refresh_base || {
        echo "NG $slug#$number origin から取り直せなかった"
        return 0
    }
    if [[ -f $state/$key && $(cat "$state/$key") == "$oid $base_oid" ]]; then
        echo "SKIP $slug#$number 前の回に止めたままの中身" >&2
        return 0
    fi
    case $(mergeable_of "$number") in
        MERGEABLE)
            if merge_pr "$number"; then
                echo "OK $slug#$number マージした"
            else
                stop_pr "競合は無いのに、マージを断られました"
            fi
            ;;
        CONFLICTING) resolve_pr ;;
        *) echo "SKIP $slug#$number GitHub がまだ判定していない" >&2 ;;
    esac
}

refresh_base() {
    git -C "$repo" fetch -q origin || return 1
    base_oid=$(git -C "$repo" rev-parse "$base")
}

run_repo() {
    local list
    repo=$(resolve_repo "$1") || return 1
    name=$(basename "$repo")
    wt=$(worktree_root "$name-pr-merge")
    base=$(default_branch "$repo") || return 1
    refresh_base || return 1
    slug=$(cd "$repo" && gh repo view --json nameWithOwner -q .nameWithOwner) || return 1
    [[ -n $slug ]] || return 1
    list=$(gh pr list --repo "$slug" --state open --base "${base#origin/}" --json number,isDraft,headRefName,headRefOid,url,title \
        --jq 'sort_by(.number)[] | select(.isDraft | not) | [.number, .headRefName, .headRefOid, .url, .title] | @tsv') || return 1
    while IFS=$'\t' read -r number head oid url title; do
        [[ -n $number ]] || continue
        handle_pr
    done <<<"$list"
}

run_all() {
    local target
    mkdir -p "$state"
    mkdir "$state/lock" 2>/dev/null || {
        echo "SKIP 前の回がまだ動いている" >&2
        exit 0
    }
    trap 'rmdir "$state/lock"' EXIT
    for target in "$@"; do
        (run_repo "$target") || echo "NG $target を回せなかった"
    done
}

install_agent() {
    local plist="$HOME/Library/LaunchAgents/$label.plist" target args=""
    for target in "$@"; do
        target=$(resolve_repo "$target") || {
            echo "$target"
            exit 1
        }
        args+="        <string>$target</string>
"
    done
    mkdir -p "$(dirname "$plist")" "$HOME/Library/Logs"
    cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$here/pr-merge.sh</string>
        <string>run</string>
$args    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$PATH</string>
    </dict>
    <key>StartInterval</key>
    <integer>1800</integer>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/pr-merge.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/pr-merge.log</string>
</dict>
</plist>
EOF
    launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$(id -u)" "$plist"
    echo "OK $plist を入れた"
}

[[ $# -ge 2 ]] || usage
mode=$1
shift
case $mode in
    run) run_all "$@" ;;
    install) install_agent "$@" ;;
    *) usage ;;
esac
