#!/usr/bin/env bash
# ashigaru_init.sh — 足軽ペインの初期化とcopilot起動

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/cli_adapter.sh" 2>/dev/null || true

AGENT_ID="$1"
PANE_INDEX="${2:-0}"
PANE_TARGET="cmultiagent:agents.${PANE_INDEX}"

echo "Initializing $AGENT_ID in $PANE_TARGET..."

# Build CLI command with -i Session Start prompt
if declare -f build_cli_command &>/dev/null; then
    LAUNCH_CMD=$(build_cli_command "$AGENT_ID")
else
    LAUNCH_CMD="copilot --yolo -i \"Session Start: あなたは${AGENT_ID}です。queue/inbox/${AGENT_ID}.yaml を読んで未読メッセージを処理してください。\""
fi

# Quit any running copilot, then launch with Session Start
tmux send-keys -t "$PANE_TARGET" C-c 2>/dev/null || true
sleep 0.5
tmux send-keys -t "$PANE_TARGET" "/q" Enter 2>/dev/null || true
sleep 1
tmux send-keys -t "$PANE_TARGET" "exit" Enter 2>/dev/null || true
sleep 1
tmux send-keys -t "$PANE_TARGET" "$LAUNCH_CMD" Enter
echo "$AGENT_ID initialized in $PANE_TARGET with: $LAUNCH_CMD"