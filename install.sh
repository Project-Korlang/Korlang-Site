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
  if [ -t 0 ]; then
    echo "Select release channel:"
    printf "1) stable\n2) alpha\n> "
    read -r CHOICE < /dev/tty
    CHANNEL="stable"
    [ "$CHOICE" = "2" ] && CHANNEL="alpha"
  else
    CHANNEL="stable"
  fi
fi

pick_latest() {
  curl -fsSL "$API" | \
    awk -v chan="$1" '
      /"tag_name":/ {
        tag=$0;
        gsub(/.*"tag_name": "|".*/, "", tag);
        if (chan=="alpha") { if (tag ~ /alpha/) { print tag; exit } }
        else { if (tag !~ /alpha/) { print tag; exit } }
      }
    '
}

LATEST=$(pick_latest "$CHANNEL")

if [ -z "$LATEST" ] && [ "$CHANNEL" = "stable" ]; then
  CHANNEL="alpha"
  LATEST=$(pick_latest "$CHANNEL")
fi

if [ -z "$LATEST" ]; then
  echo "Failed to detect latest release" >&2
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
  echo '\nexport PATH="$HOME/.korlang/bin:$PATH"' >> "$PROFILE"
fi

if ! grep -q 'KORLANG_HOME' "$PROFILE" 2>/dev/null; then
  echo '\nexport KORLANG_HOME="$HOME/.korlang"' >> "$PROFILE"
fi

echo "Korlang installed from $LATEST ($CHANNEL). Restart your shell."
