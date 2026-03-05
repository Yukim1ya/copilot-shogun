#!/usr/bin/env bash
# system_status.sh — copilot-shogun システム全体のヘルス確認
#
# Usage:
#   bash scripts/system_status.sh          # 人間向けカラー表示
#   bash scripts/system_status.sh --json   # JSON出力（自動化向け）
#
# 各エージェントについて表示:
#   - idle/busy 状態（idle flag ファイルの有無）
#   - inbox 未読メッセージ数
#   - inbox_watcher プロセスの生死
#   - tmux ペインの生死
#   - 最終活動時刻（最新レポートまたはinboxの更新時刻）

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

JSON_MODE=0
[[ "${1:-}" == "--json" ]] && JSON_MODE=1

IDLE_FLAG_DIR="${IDLE_FLAG_DIR:-$SCRIPT_DIR/queue/status}"

# ─── Agent configuration (keep in sync with watcher_supervisor.sh) ─────────
AGENTS=(
    "shogun:cshogun:main.0"
    "karo:cmultiagent:command.1"
    "gunshi:cmultiagent:command.0"
    "ashigaru1:cmultiagent:agents.0"
    "ashigaru2:cmultiagent:agents.1"
    "ashigaru3:cmultiagent:agents.2"
    "ashigaru4:cmultiagent:agents.3"
    "ashigaru5:cmultiagent:agents.4"
    "ashigaru6:cmultiagent:agents.5"
    "ashigaru7:cmultiagent:agents.6"
)
# ───────────────────────────────────────────────────────────────────────────

# Color codes (suppressed in JSON mode)
if [[ $JSON_MODE -eq 0 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

pane_exists() {
    tmux list-panes -a -F "#{session_name}:#{window_name}.#{pane_index}" 2>/dev/null | grep -qx "$1"
}

watcher_running() {
    local agent="$1" pane="$2"
    pgrep -f "inbox_watcher.sh ${agent} ${pane} " >/dev/null 2>&1 || \
    pgrep -f "inbox_watcher.sh ${agent} ${pane}$" >/dev/null 2>&1
}

count_unread() {
    local inbox="queue/inbox/${1}.yaml"
    [[ ! -f "$inbox" ]] && echo 0 && return
    python3 -c "
import yaml, sys
try:
    data = yaml.safe_load(open('$inbox'))
    msgs = data.get('messages', []) if data else []
    print(sum(1 for m in msgs if not m.get('read', False)))
except:
    print(0)
" 2>/dev/null || echo 0
}

last_activity() {
    local agent="$1"
    # Check latest report file or inbox modification time
    local latest_time=""
    local inbox="queue/inbox/${agent}.yaml"
    local report
    report=$(ls -t queue/reports/${agent}_*.yaml 2>/dev/null | head -1 || true)

    if [[ -n "$report" ]]; then
        latest_time=$(date -r "$report" "+%H:%M:%S" 2>/dev/null || echo "?")
        echo "$latest_time (report)"
    elif [[ -f "$inbox" ]]; then
        latest_time=$(date -r "$inbox" "+%H:%M:%S" 2>/dev/null || echo "?")
        echo "$latest_time (inbox)"
    else
        echo "-"
    fi
}

is_idle() {
    [[ -f "${IDLE_FLAG_DIR}/shogun_idle_${1}" ]]
}

now=$(date "+%Y-%m-%d %H:%M:%S %Z")

if [[ $JSON_MODE -eq 0 ]]; then
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║         copilot-shogun システムステータス               ║${RESET}"
    printf "${BOLD}║  %-55s║${RESET}\n" "$now"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    printf "${BOLD}%-12s %-22s %-7s %-8s %-8s %-16s${RESET}\n" \
        "エージェント" "ペイン" "状態" "未読" "Watcher" "最終活動"
    echo "────────────────────────────────────────────────────────────────────────────"
fi

json_entries=()

for entry in "${AGENTS[@]}"; do
    agent="${entry%%:*}"
    pane="${entry#*:}"

    # Gather status
    pane_ok=0; pane_exists "$pane" && pane_ok=1
    watch_ok=0; watcher_running "$agent" "$pane" && watch_ok=1
    idle_ok=0; is_idle "$agent" && idle_ok=1
    unread=$(count_unread "$agent")
    last_act=$(last_activity "$agent")

    # Determine health state
    if [[ $pane_ok -eq 0 ]]; then
        state="PANE_GONE"; state_color="$RED"
    elif [[ $watch_ok -eq 0 ]]; then
        state="NO_WATCHER"; state_color="$YELLOW"
    elif [[ $idle_ok -eq 1 && $unread -eq 0 ]]; then
        state="idle"; state_color="$GREEN"
    elif [[ $idle_ok -eq 1 && $unread -gt 0 ]]; then
        state="PENDING"; state_color="$YELLOW"
    elif [[ $idle_ok -eq 0 && $unread -gt 0 ]]; then
        state="busy"; state_color="$CYAN"
    else
        state="busy"; state_color="$CYAN"
    fi

    pane_sym="✓"; [[ $pane_ok -eq 0 ]] && pane_sym="✗"
    watch_sym="✓"; [[ $watch_ok -eq 0 ]] && watch_sym="✗"

    if [[ $JSON_MODE -eq 0 ]]; then
        printf "%-12s %-22s ${state_color}%-7s${RESET} %-8s %-8s %-16s\n" \
            "$agent" "$pane" "$state" "$unread" "${watch_sym}watcher" "$last_act"
    else
        json_entries+=("{\"agent\":\"$agent\",\"pane\":\"$pane\",\"pane_exists\":$pane_ok,\"watcher_running\":$watch_ok,\"is_idle\":$idle_ok,\"unread\":$unread,\"state\":\"$state\",\"last_activity\":\"$last_act\"}")
    fi
done

if [[ $JSON_MODE -eq 0 ]]; then
    echo ""
    # Summary
    total=${#AGENTS[@]}
    idle_count=0; stuck_count=0; gone_count=0
    for entry in "${AGENTS[@]}"; do
        agent="${entry%%:*}"
        pane="${entry#*:}"
        if ! pane_exists "$pane"; then
            (( gone_count++ )) || true
        elif is_idle "$agent" && [[ $(count_unread "$agent") -eq 0 ]]; then
            (( idle_count++ )) || true
        elif ! watcher_running "$agent" "$pane"; then
            (( stuck_count++ )) || true
        fi
    done
    echo -e "${BOLD}Summary:${RESET} $total agents — ${GREEN}${idle_count} idle${RESET} / ${RED}${gone_count} pane gone${RESET} / ${YELLOW}${stuck_count} no watcher${RESET}"
    echo ""
else
    echo "{"
    echo "  \"timestamp\": \"$now\","
    echo "  \"agents\": ["
    for i in "${!json_entries[@]}"; do
        if [[ $i -lt $((${#json_entries[@]}-1)) ]]; then
            echo "    ${json_entries[$i]},"
        else
            echo "    ${json_entries[$i]}"
        fi
    done
    echo "  ]"
    echo "}"
fi
