#!/usr/bin/env sh
set -e

# 1. Normalize OS and ARCH to match workflow output
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="x86_64";;
  arm64|aarch64) ARCH="aarch64";;
esac

REPO="Project-Korlang/Korlang-Site"
API="https://api.github.com/repos/$REPO/releases"

# 2. Channel Selection
CHANNEL="${KORLANG_CHANNEL:-${1:-}}"
if [ -z "$CHANNEL" ]; then
  if [ -t 0 ]; then
    printf "Select release channel:\n1) stable\n2) alpha\n> "
    read -r CHOICE
    CHANNEL="stable"
    [ "$CHOICE" = "2" ] && CHANNEL="alpha"
  else
    CHANNEL="stable"
  fi
fi

# 3. Version Detection
fetch_tags() {
  curl -fsSL -H "Accept: application/vnd.github+json" "$API?per_page=100" | \
    sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p'
}

if [ -n "$KORLANG_VERSION" ]; then
  LATEST="$KORLANG_VERSION"
elif [ "$CHANNEL" = "alpha" ]; then
  LATEST="alpha-latest" # Directly target your rolling tag
else
  LATEST=$(fetch_tags | grep -vi 'alpha' | head -n1)
fi

if [ -z "$LATEST" ]; then
  echo "Error: Could not find a release for channel: $CHANNEL" >&2
  exit 1
fi

# 4. Construct Filename (Matching the new Workflow)
if [ "$OS" = "darwin" ]; then OS="macos"; fi # Workflow uses 'macos' label

# Determine extension
EXT="tar.gz"
if [ "$OS" = "windows" ]; then EXT="zip"; fi

TARBALL="korlang-${LATEST}-${OS}-${ARCH}.${EXT}"
URL="https://github.com/$REPO/releases/download/$LATEST/$TARBALL"

echo "Downloading Korlang $LATEST for $OS-$ARCH..."

DEST="$HOME/.korlang"
mkdir -p "$DEST"

# 5. Download and Extract
curl -fsSL "$URL" -o "/tmp/$TARBALL"
if [ "$EXT" = "zip" ]; then
  unzip -o "/tmp/$TARBALL" -d "$DEST"
else
  tar -xzf "/tmp/$TARBALL" -C "$DEST" --strip-components=1
fi

# 6. Setup Paths
# (Remaining logic for .bashrc / .zshrc is fine)
