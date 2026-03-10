#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${1:-$HOME/.local/bin}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/oc-notify" "$INSTALL_DIR/oc-notify"
chmod +x "$INSTALL_DIR/oc-notify"

echo "Installed oc-notify to $INSTALL_DIR/oc-notify"
echo ""
echo "Add to your opencode-notifier.json:"
echo '  "command": {'
echo '    "enabled": true,'
echo "    \"path\": \"$INSTALL_DIR/oc-notify\","
echo '    "args": ["{event}", "{message}", "{sessionTitle}", "{projectName}", "{timestamp}", "{turn}"],'
echo '    "minDuration": 0'
echo '  }'
