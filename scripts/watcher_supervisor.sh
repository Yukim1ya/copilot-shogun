#!/usr/bin/env bash
set -euo pipefail

# Keep inbox watchers alive in a persistent tmux-hosted shell.
# This script is designed to run forever.
#
# Agent↔pane mapping is declared in AGENTS array below.
# Format: "agent_id:session:window.pane"
# To add/remove agents, edit only this array.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

mkdir -p logs queue/inbox queue/status

# ─── Agent configuration ───────────────────────────────────────────────────
# Format: "agent_id:pane_target"
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

ensure_inbox_file() {
    local agent="$1"
    if [ ! -f "queue/inbox/${agent}.yaml" ]; then
        printf 'messages: []\n' > "queue/inbox/${agent}.yaml"
    fi
}

pane_exists() {
    local pane="$1"
    tmux list-panes -a -F "#{session_name}:#{window_name}.#{pane_index}" 2>/dev/null | grep -qx "$pane"
}

start_watcher_if_missing() {
    local agent="$1"
    local pane="$2"
    local log_file="logs/inbox_watcher_${agent}.log"
    local cli

    ensure_inbox_file "$agent"
    if ! pane_exists "$pane"; then
        return 0
    fi

    if pgrep -f "inbox_watcher.sh ${agent} ${pane} " >/dev/null 2>&1 || \
       pgrep -f "inbox_watcher.sh ${agent} ${pane}$" >/dev/null 2>&1; then
        return 0
    fi

    cli=$(tmux show-options -p -t "$pane" -v @agent_cli 2>/dev/null || echo "codex")
    echo "[$(date)] Starting watcher for ${agent} on ${pane} (cli=${cli})" >> "$log_file"
    nohup bash scripts/inbox_watcher.sh "$agent" "$pane" "$cli" >> "$log_file" 2>&1 &
}

while true; do
    for entry in "${AGENTS[@]}"; do
        agent="${entry%%:*}"
        pane="${entry#*:}"
        start_watcher_if_missing "$agent" "$pane"
    done
    sleep 5
done
