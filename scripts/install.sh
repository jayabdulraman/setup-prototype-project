#!/usr/bin/env bash
# install.sh — make the setup-prototype-project skill available to every coding agent on this machine.
#
#   bash install.sh                 global: ~/.agents/skills/setup-prototype-project, linked into ~/.claude and ~/.cursor
#   bash install.sh --project DIR   project only: DIR/.agents/skills/setup-prototype-project, linked into DIR/.claude
#
# Global is tried first; if it can't write there, it falls back to the current folder.
# Re-run after editing the source to update the installed copy.
# Windows: run in Git Bash. Symlinks need admin there, so each agent folder gets a copy.
set -euo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=setup-prototype-project

copy_skill() { # DEST
  local dest=$1
  [[ "$(cd "$dest" 2>/dev/null && pwd)" == "$SRC" ]] && return 0
  mkdir -p "$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --exclude '.DS_Store' "$SRC/" "$dest/"
  else
    rm -rf "${dest:?}"/* && cp -R "$SRC/." "$dest/" && rm -f "$dest/.DS_Store"
  fi
  chmod +x "$dest"/scripts/*.sh 2>/dev/null || true
}

is_windows() { case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) return 0 ;; *) return 1 ;; esac; }

link_into() { # AGENT_SKILLS_DIR TARGET_RELATIVE
  local dir=$1 rel=$2 link="$1/$NAME"
  mkdir -p "$dir"
  if is_windows; then
    copy_skill "$link"
    echo "  copied  $link"
    return 0
  fi
  if [[ -e "$link" && ! -L "$link" ]]; then
    echo "  skipped $link (a real folder is already there; remove it to link instead)"
    return 0
  fi
  ln -sfn "$rel" "$link"
  echo "  linked  $link"
}

install_global() {
  local dest="$HOME/.agents/skills/$NAME"
  copy_skill "$dest" || return 1
  echo "Installed $NAME globally at $dest (Codex and other agents read ~/.agents/skills)"
  link_into "$HOME/.claude/skills" "../../.agents/skills/$NAME"
  [[ -d "$HOME/.cursor" ]] && link_into "$HOME/.cursor/skills" "../../.agents/skills/$NAME"
  return 0
}

install_project() { # DIR
  local root; root=$(cd "$1" && pwd)
  copy_skill "$root/.agents/skills/$NAME"
  echo "Installed $NAME for this project at $root/.agents/skills/$NAME"
  link_into "$root/.claude/skills" "../../.agents/skills/$NAME"
  link_into "$root/.cursor/skills" "../../.agents/skills/$NAME"
}

if [[ "${1:-}" == "--project" ]]; then
  install_project "${2:-.}"
elif ! install_global; then
  echo "Couldn't install globally; installing into the current folder instead."
  install_project "."
fi
echo "Done. Start a new agent session, then ask: \"prototype my idea\" (Claude Code: /setup-prototype-project)."
