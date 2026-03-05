#!/usr/bin/env bash
# restart_all_agents.sh — 全エージェントを -i (Session Start) モードで再起動

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"
source lib/cli_adapter.sh

restart_agent() {
    local agent_id="$1"
    local pane="$2"
    local launch_cmd
    launch_cmd=$(build_cli_command "$agent_id")
    echo "Restarting $agent_id in $pane: $launch_cmd"
    tmux send-keys -t "$pane" Escape 2>/dev/null || true
    sleep 0.2
    tmux send-keys -t "$pane" C-u 2>/dev/null || true
    sleep 0.2
    tmux send-keys -t "$pane" "/q" Enter 2>/dev/null || true
    sleep 1.5
    tmux send-keys -t "$pane" "exit" Enter 2>/dev/null || true
    sleep 1
    tmux send-keys -t "$pane" "$launch_cmd" Enter
    sleep 0.5
}

echo "=== Restarting all agents with -i Session Start mode ==="
restart_agent "karo"      "cmultiagent:command.0"
restart_agent "gunshi"    "cmultiagent:command.1"
restart_agent "ashigaru1" "cmultiagent:agents.0"
restart_agent "ashigaru2" "cmultiagent:agents.1"
restart_agent "ashigaru3" "cmultiagent:agents.2"
restart_agent "ashigaru4" "cmultiagent:agents.3"
restart_agent "ashigaru5" "cmultiagent:agents.4"
restart_agent "ashigaru6" "cmultiagent:agents.5"
restart_agent "ashigaru7" "cmultiagent:agents.6"
echo "=== All agents restarting. Session Start will auto-execute. ==="
