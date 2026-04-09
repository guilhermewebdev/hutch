#!/usr/bin/env bash
# Uninstalls hutch and optionally removes associated data.
#
# Local:  ./uninstall.sh
# Remote: curl -fsSL https://raw.githubusercontent.com/guilhermewebdev/hutch/main/uninstall.sh | bash
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
HUTCH_BIN="$BIN_DIR/hutch"
PROFILES_DIR="$HOME/.config/hutch"
DEFAULT_INSTALL_DIR="$HOME/.local/share/hutch"

# --- Helpers ---

_confirm() {
  local prompt="$1"
  local yn
  # When piped via curl/wget, stdin is the script itself — force /dev/tty
  read -r -p "$prompt [y/N] " yn </dev/tty
  [[ "${yn:-n}" =~ ^[Yy]$ ]]
}

_section() { echo ""; echo "── $* ──"; }

# --- Find install dir ---

INSTALL_DIR=""
if [ -L "$HUTCH_BIN" ]; then
  INSTALL_DIR="$(dirname "$(readlink -f "$HUTCH_BIN")")"
fi

echo ""
echo "Hutch uninstaller"
echo ""
echo "  bin:      ${HUTCH_BIN}"
echo "  install:  ${INSTALL_DIR:-(not found via symlink)}"
echo "  profiles: ${PROFILES_DIR}"
echo ""

if ! _confirm "Proceed with uninstall?"; then
  echo "Aborted."
  exit 0
fi

# --- Remove bin ---

_section "Command"

if [ -L "$HUTCH_BIN" ] || [ -f "$HUTCH_BIN" ]; then
  rm "$HUTCH_BIN"
  echo "✓ Removed $HUTCH_BIN"
else
  echo "  hutch command not found at $HUTCH_BIN (already removed?)"
fi

# --- Profiles ---

_section "Profiles"

if [ -d "$PROFILES_DIR" ]; then
  local_count="$(find "$PROFILES_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  echo "  $PROFILES_DIR ($local_count file(s)):"
  find "$PROFILES_DIR" -maxdepth 1 -type f -exec basename {} \; | sort | sed 's/^/    /'
  echo ""
  if _confirm "Remove profiles directory?"; then
    rm -rf "$PROFILES_DIR"
    echo "✓ Removed $PROFILES_DIR"
  else
    echo "  Kept."
  fi
else
  echo "  $PROFILES_DIR not found."
fi

# --- Docker volumes ---

_section "Docker volumes"

if command -v docker &>/dev/null; then
  # Hutch volumes are named <profile>_home — collect candidates
  # Cross-reference with known profiles when possible
  HUTCH_VOLS="$(docker volume ls --format '{{.Name}}' 2>/dev/null \
    | grep -E '^[a-zA-Z0-9_-]+_home$' || true)"

  if [ -z "$HUTCH_VOLS" ]; then
    echo "  No hutch volumes found."
  else
    echo "  Volumes matching hutch naming pattern (*_home):"
    echo "$HUTCH_VOLS" | sed 's/^/    /'
    echo ""
    if _confirm "Remove these volumes? (this deletes credentials, git config, SSH keys stored in each profile)"; then
      echo "$HUTCH_VOLS" | while read -r vol; do
        docker volume rm "$vol" && echo "  ✓ Removed $vol" || echo "  ✗ Failed to remove $vol"
      done
    else
      echo "  Kept."
    fi
  fi

  # DinD cert volumes
  DIND_VOLS="$(docker volume ls --format '{{.Name}}' 2>/dev/null \
    | grep -E '^[a-zA-Z0-9_-]+_dind_certs$' || true)"

  if [ -n "$DIND_VOLS" ]; then
    echo ""
    echo "  DinD cert volumes:"
    echo "$DIND_VOLS" | sed 's/^/    /'
    echo ""
    if _confirm "Remove DinD cert volumes?"; then
      echo "$DIND_VOLS" | while read -r vol; do
        docker volume rm "$vol" && echo "  ✓ Removed $vol" || echo "  ✗ Failed to remove $vol"
      done
    else
      echo "  Kept."
    fi
  fi
else
  echo "  docker not available — skipping."
fi

# --- Docker images ---

_section "Docker images"

if command -v docker &>/dev/null; then
  HUTCH_IMGS="$(docker images "hutch-*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)"

  if [ -z "$HUTCH_IMGS" ]; then
    echo "  No hutch-* images found."
  else
    echo "  hutch-* images:"
    echo "$HUTCH_IMGS" | sed 's/^/    /'
    echo ""
    if _confirm "Remove these images?"; then
      echo "$HUTCH_IMGS" | while read -r img; do
        docker rmi "$img" && echo "  ✓ Removed $img" || echo "  ✗ Failed to remove $img"
      done
    else
      echo "  Kept."
    fi
  fi
else
  echo "  docker not available — skipping."
fi

# --- Installation directory ---

_section "Installation directory"

# Only offer to remove if it's the default managed directory
if [ -d "$DEFAULT_INSTALL_DIR" ]; then
  echo "  $DEFAULT_INSTALL_DIR"
  echo "  (contains bases/, images/, and any custom files you may have created)"
  echo ""
  if _confirm "Remove installation directory?"; then
    rm -rf "$DEFAULT_INSTALL_DIR"
    echo "✓ Removed $DEFAULT_INSTALL_DIR"
  else
    echo "  Kept."
  fi
elif [ -n "$INSTALL_DIR" ] && [ "$INSTALL_DIR" != "$DEFAULT_INSTALL_DIR" ]; then
  echo "  Hutch was installed from a custom location: $INSTALL_DIR"
  echo "  Skipping — remove it manually if desired."
else
  echo "  $DEFAULT_INSTALL_DIR not found."
fi

# --- Done ---

echo ""
echo "Done."
