#!/usr/bin/env bash
set -euo pipefail

# ─── configuration ───────────────────────────────────────────────────────────
INSTALL_DIR=${INSTALL_DIR:-"$HOME/.local/bin"}   # override with env var
SCRIPT_NAME="file_dump"                          # final executable name
ALIAS_NAME="fdump"                               # bash-rc alias
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_FILE="$SRC_DIR/file_dump.sh"
BASHRC="$HOME/.bashrc"

# ─── install binary ──────────────────────────────────────────────────────────
echo "→ Installing $SCRIPT_NAME into $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
install -m 0755 "$SRC_FILE" "$INSTALL_DIR/$SCRIPT_NAME"

# ─── add alias if absent ─────────────────────────────────────────────────────
if ! grep -qE "^alias $ALIAS_NAME=" "$BASHRC"; then
  {
    echo ""
    echo "# added by file_dump installer ($(date +%F))"
    echo "alias $ALIAS_NAME='$SCRIPT_NAME \"\$(git -C . rev-parse --show-toplevel 2>/dev/null || pwd)\"'"
  } >> "$BASHRC"
  echo "→ Added alias '$ALIAS_NAME' to $BASHRC"
else
  echo "→ Alias '$ALIAS_NAME' already present in $BASHRC"
fi

echo "✔ Installation complete.  Open a new shell or run:  source \"$BASHRC\""
