#!/usr/bin/env bash
# ignore-sync.sh — stop Dropbox from syncing a prototype's heavy, rebuildable folders
# (node_modules, .next, test output). The folders stay on this computer; Dropbox just skips them.
# Usage: bash ignore-sync.sh <project-dir>
set -euo pipefail

cd "${1:-.}"
case "$(pwd)" in
  *Dropbox*) ;;
  *) echo "Not inside a Dropbox folder; nothing to do."; exit 0 ;;
esac

for d in node_modules .next test-results playwright-report; do
  mkdir -p "$d"
  case "$(uname -s)" in
    Darwin)
      # Classic Dropbox and Dropbox on macOS File Provider (~/Library/CloudStorage) use different markers.
      xattr -w com.dropbox.ignored 1 "$d" 2>/dev/null || true
      xattr -w 'com.apple.fileprovider.ignore#P' 1 "$d" 2>/dev/null || true ;;
    Linux)
      attr -s com.dropbox.ignored -V 1 "$d" >/dev/null 2>&1 || setfattr -n user.com.dropbox.ignored -v 1 "$d" 2>/dev/null || true ;;
    MINGW*|MSYS*|CYGWIN*)
      powershell.exe -NoProfile -Command "Set-Content -Path '$(cygpath -w "$(pwd)/$d")' -Stream com.dropbox.ignored -Value 1" || true ;;
  esac
  echo "  Dropbox will skip $d/"
done
