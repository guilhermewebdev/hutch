#!/usr/bin/env bash
# Installs the `hutch` command globally and sets up the profiles directory.
#
# Local:  ./install.sh
# Remote: curl -fsSL https://raw.githubusercontent.com/guilhermewebdev/hutch/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/guilhermewebdev/hutch.git"
DEFAULT_INSTALL_DIR="$HOME/.local/share/hutch"
BIN_DIR="$HOME/.local/bin"
PROFILES_DIR="$HOME/.config/hutch"

# Detect remote execution (piped via curl/wget — no local files present)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-install.sh}")" && pwd 2>/dev/null || echo "")"
if [ ! -f "$SCRIPT_DIR/hutch" ]; then
  echo "Remote install detected. Cloning hutch to $DEFAULT_INSTALL_DIR..."
  if [ -d "$DEFAULT_INSTALL_DIR/.git" ]; then
    git -C "$DEFAULT_INSTALL_DIR" pull --ff-only
    echo "✓ Updated existing installation"
  else
    git clone "$REPO" "$DEFAULT_INSTALL_DIR"
    echo "✓ Cloned to $DEFAULT_INSTALL_DIR"
  fi
  SCRIPT_DIR="$DEFAULT_INSTALL_DIR"
fi

# Install `hutch` command
mkdir -p "$BIN_DIR"
ln -sf "$SCRIPT_DIR/hutch" "$BIN_DIR/hutch"
chmod +x "$SCRIPT_DIR/hutch"
echo "✓ Command 'hutch' installed at $BIN_DIR/hutch"

# Create profiles directory
mkdir -p "$PROFILES_DIR"
echo "✓ Profiles directory: $PROFILES_DIR"

# Copy default profiles if they don't exist yet
for example in "$SCRIPT_DIR/profiles/"*; do
  [ -f "$example" ] || continue
  name="$(basename "$example")"
  dest="$PROFILES_DIR/$name"
  if [ ! -f "$dest" ]; then
    cp "$example" "$dest"
    echo "  + Profile created: $dest"
  else
    echo "  ~ Profile already exists (kept): $dest"
  fi
done

echo ""

# Check PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
  echo "WARNING: $BIN_DIR is not in your PATH."
  echo "Add to ~/.bashrc or ~/.zshrc:"
  echo ""
  echo '  export PATH="$HOME/.local/bin:$PATH"'
  echo ""
fi

echo "Done. Next steps:"
echo ""
echo "  List profiles:   hutch list"
echo "  List bases:      hutch list bases"
echo "  Build an image:  hutch build claude"
echo "  Run:             hutch <profile>"
echo ""
echo "To create new environments:"
echo "  hutch new image <name>   create a Dockerfile"
echo "  hutch new base <name>    create a docker-compose base"
echo ""
echo "Edit profiles in $PROFILES_DIR to customize."
