#!/usr/bin/env bash
# restart_all_agents.sh — 全エージェントを -i (Session Start) モードで再起動
#
# IMPORTANT: Never send `exit` to agent panes — it closes the tmux pane entirely.
# Sequence: /q → wait → send new launch command (bash shell stays alive after /q).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"
source lib/cli_adapter.sh

# ─── Agent configuration (keep in sync with watcher_supervisor.sh) ─────────
AGENTS=(
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

restart_agent() {
    local agent_id="$1"
    local pane="$2"
    local launch_cmd
    launch_cmd=$(build_cli_command "$agent_id")
    echo "Restarting $agent_id in $pane"
    # Step 1: interrupt + quit current copilot session
    tmux send-keys -t "$pane" C-c 2>/dev/null || true
    sleep 0.2
    tmux send-keys -t "$pane" C-u 2>/dev/null || true
    sleep 0.2
    tmux send-keys -t "$pane" "/q" Enter 2>/dev/null || true
    # Step 2: wait for copilot to exit (returns to bash prompt)
    sleep 2.5
    # Step 3: launch new session (DO NOT send `exit` — it closes the pane)
    tmux send-keys -t "$pane" "cd $SCRIPT_DIR && $launch_cmd" Enter
    sleep 0.5
}

echo "=== Restarting all agents with -i Session Start mode ==="
for entry in "${AGENTS[@]}"; do
    agent="${entry%%:*}"
    pane="${entry#*:}"
    restart_agent "$agent" "$pane"
done
echo "=== All agents restarting. Session Start will auto-execute. ==="
