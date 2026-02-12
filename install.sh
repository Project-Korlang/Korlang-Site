#!/usr/bin/env sh
set -e

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="x86_64";;
  arm64|aarch64) ARCH="aarch64";;
esac

REPO="Project-Korlang/Korlang-Site"
API="https://api.github.com/repos/$REPO/releases"

CHANNEL="${KORLANG_CHANNEL:-${1:-}}"
if [ -z "$CHANNEL" ]; then
  if [ -r /dev/tty ]; then
    printf "Select release channel:\n1) stable\n2) alpha\n> " > /dev/tty
    read -r CHOICE < /dev/tty || CHOICE=""
    CHANNEL="stable"
    [ "$CHOICE" = "2" ] && CHANNEL="alpha"
  else
    CHANNEL="stable"
  fi
fi

fetch_tags() {
  curl -fsSL -H "Accept: application/vnd.github+json" "$API?per_page=100" | \
    sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p'
}

pick_latest() {
  if [ "$1" = "alpha" ]; then
    fetch_tags | grep -i 'alpha' | head -n1
  else
    fetch_tags | grep -vi 'alpha' | head -n1
  fi
}

if [ -n "$KORLANG_VERSION" ]; then
  LATEST="$KORLANG_VERSION"
else
  LATEST=$(pick_latest "$CHANNEL")

  if [ -z "$LATEST" ] && [ "$CHANNEL" = "stable" ]; then
    CHANNEL="alpha"
    LATEST=$(pick_latest "$CHANNEL")
  fi
fi

if [ -z "$LATEST" ]; then
  echo "Failed to detect latest $CHANNEL version" >&2
  exit 1
fi

TARBALL="korlang-${LATEST}-${OS}-${ARCH}.tar.gz"
URL="https://github.com/$REPO/releases/download/$LATEST/$TARBALL"

DEST="$HOME/.korlang"
mkdir -p "$DEST"

curl -fsSL "$URL" | tar -xz -C "$DEST"

PROFILE="$HOME/.bashrc"
[ -n "$ZSH_VERSION" ] && PROFILE="$HOME/.zshrc"

if ! grep -q 'korlang/bin' "$PROFILE" 2>/dev/null; then
  printf '\nexport PATH="$HOME/.korlang/bin:$PATH"' >> "$PROFILE"
  printf '\n' >> "$PROFILE"
fi

if ! grep -q 'KORLANG_HOME' "$PROFILE" 2>/dev/null; then
  printf '\nexport KORLANG_HOME="$HOME/.korlang"' >> "$PROFILE"
  printf '\n' >> "$PROFILE"
fi

echo "Korlang installed from $LATEST ($CHANNEL). Restart your shell."
