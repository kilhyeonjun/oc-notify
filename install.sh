#!/usr/bin/env bash
# oc-notify installer
set -euo pipefail

INSTALL_DIR="${1:-$HOME/.local/bin}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check dependencies
if ! command -v terminal-notifier &>/dev/null; then
  echo "terminal-notifier not found. Installing via Homebrew..."
  if command -v brew &>/dev/null; then
    brew install terminal-notifier
  else
    echo "Error: Homebrew not found. Install terminal-notifier manually:" >&2
    echo "  brew install terminal-notifier" >&2
    exit 1
  fi
fi

# Install
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/oc-notify" "$INSTALL_DIR/oc-notify"
chmod +x "$INSTALL_DIR/oc-notify"

echo "Installed oc-notify to $INSTALL_DIR/oc-notify"

# Create default config if not exists
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/oc-notify"
if [[ ! -f "$CONFIG_DIR/config" ]]; then
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_DIR/config" << 'EOF'
# oc-notify configuration
# Terminal app bundle ID (focus this app on notification click)
# Ghostty:  com.mitchellh.ghostty
# iTerm2:   com.googlecode.iterm2
# Terminal: com.apple.Terminal
TERMINAL_BUNDLE_ID="com.mitchellh.ghostty"

# Path to terminal-notifier (auto-detected if empty)
# NOTIFIER="/opt/homebrew/bin/terminal-notifier"

# Play sound via terminal-notifier (default: false, opencode-notifier handles sound)
PLAY_SOUND="false"

# tmux session to switch to on click (empty = just focus terminal)
# TMUX_TARGET="main"
EOF
  echo "Created config at $CONFIG_DIR/config"
fi

echo ""
echo "Add to your opencode-notifier.json:"
echo '  "command": {'
echo '    "enabled": true,'
echo "    \"path\": \"$INSTALL_DIR/oc-notify\","
echo '    "args": ["{event}", "{message}", "{sessionTitle}", "{projectName}", "{timestamp}", "{turn}"],'
echo '    "minDuration": 0'
echo '  }'
