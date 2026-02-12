#!/usr/bin/env sh
set -e

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="x86_64";;
  arm64|aarch64) ARCH="aarch64";;
esac

REPO="project-korlang/korlang"
API="https://api.github.com/repos/$REPO/releases/latest"

VERSION=$(curl -fsSL "$API" | grep '"tag_name"' | sed -E 's/.*"(v[^"]+)".*/\1/')

if [ -z "$VERSION" ]; then
  echo "Failed to detect latest version" >&2
  exit 1
fi

TARBALL="korlang-${VERSION}-${OS}-${ARCH}.tar.gz"
URL="https://github.com/$REPO/releases/download/$VERSION/$TARBALL"

DEST="$HOME/.korlang/bin"
mkdir -p "$DEST"

curl -fsSL "$URL" | tar -xz -C "$DEST"

PROFILE="$HOME/.bashrc"
[ -n "$ZSH_VERSION" ] && PROFILE="$HOME/.zshrc"

if ! grep -q 'korlang/bin' "$PROFILE" 2>/dev/null; then
  echo '\nexport PATH="$HOME/.korlang/bin:$PATH"' >> "$PROFILE"
fi

echo "Korlang installed. Restart your shell."
