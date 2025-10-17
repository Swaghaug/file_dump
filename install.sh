#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR=${INSTALL_DIR:-"$HOME/.local/bin"}
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/file_dump"
SCRIPT_NAME="file_dump"
ALIAS_NAME="fdump"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHRC="$HOME/.bashrc"

echo "→ Installing $SCRIPT_NAME into $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
install -m 0755 "$SRC_DIR/file_dump.sh" "$INSTALL_DIR/$SCRIPT_NAME"

echo "→ Installing default excluded_filetypes.txt"
mkdir -p "$CONFIG_DIR"
install -m 0644 "$SRC_DIR/excluded_filetypes.txt" "$CONFIG_DIR/excluded_filetypes.txt"
install -m 0644 "$SRC_DIR/excluded_filetypes.txt" "$INSTALL_DIR/excluded_filetypes.txt" || true

if ! grep -qE "^alias $ALIAS_NAME=" "$BASHRC"; then
  {
    echo ""
    echo "# added by file_dump installer ($(date +%F))"
    echo "alias $ALIAS_NAME='$SCRIPT_NAME \"\$(git -C . rev-parse --show-toplevel 2>/dev/null || pwd)\"'"
  } >>"$BASHRC"
  echo "→ Added alias '$ALIAS_NAME' to $BASHRC"
else
  echo "→ Alias '$ALIAS_NAME' already present in $BASHRC"
fi

echo "✔ Installation complete.  Run: 'source $BASHRC' or open a new shell."