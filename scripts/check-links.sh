#!/usr/bin/env bash
# Check for broken internal links and anchors in the built site.
# hyperlink (https://github.com/untitaker/hyperlink) must be on PATH or in ~/.cargo/bin.
set -euo pipefail

HYPERLINK=$(command -v hyperlink 2>/dev/null || echo "$HOME/.cargo/bin/hyperlink")
if [ ! -x "$HYPERLINK" ]; then
  echo "hyperlink not found. Install with: cargo install --locked hyperlink"
  exit 1
fi

DIST="$(cd "$(dirname "$0")/.." && pwd)/dist"
if [ ! -d "$DIST" ]; then
  echo "dist/ not found. Run 'npm run build' first."
  exit 1
fi

# hyperlink resolves absolute paths relative to the directory passed on the command line,
# so /hts-specs-md/... would need dist/hts-specs-md/ to exist.
# Create a temporary sibling directory with that structure.
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/hts-specs-md"
cp -r "$DIST/." "$TMPDIR/hts-specs-md/"

"$HYPERLINK" "$TMPDIR/" --check-anchors --sources src/_posts/
