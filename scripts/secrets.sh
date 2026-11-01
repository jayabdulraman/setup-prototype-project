#!/usr/bin/env bash
# secrets.sh — keep a prototype's app keys in the OS credential store and move
# them to and from Vercel without ever printing a value.
#
#   macOS    Keychain (generic password, service "prototype:<project>:<NAME>")
#   Windows  Credential Manager via wincred.ps1 (Git Bash, or WSL with powershell.exe)
#   Linux    Secret Service via secret-tool
#   other    git-ignored, owner-only .env.local
#
# Key names (never values) are listed in <project>/.prototype/keys.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash secrets.sh <command> [args]   (run inside the project folder)

  ask NAME [HINT]     Open a hidden-input dialog on screen and store what's pasted. Agent-friendly.
  set NAME            Prompt in this terminal (hidden) and store it. Needs an interactive terminal.
  set NAME --stdin    Read the value from a pipe, e.g. from a provider CLI.
  list                Show stored key names (never values).
  has NAME            Exit 0 if NAME is stored.
  remove NAME         Delete NAME.
  run -- CMD...       Run CMD with every stored key in its environment.
  write-env [FILE]    Write keys to a git-ignored env file (default .env.local).
  import-env FILE     Store every KEY=value in FILE, then you can delete FILE.
  push-vercel NAME [ENV...] [--plain]
                      Copy NAME to Vercel (default: production preview development).
                      Production/preview are marked sensitive unless --plain.
  pull-vercel [ENV]   Copy Vercel's variables for ENV (default development) into storage.
  diff-vercel         Compare local key names with each Vercel environment.

Env: PROTOTYPE_PROJECT overrides the project name (default: git root folder name).
EOF
}

die() { echo "secrets: $*" >&2; exit 1; }

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT=${PROTOTYPE_PROJECT:-$(basename "$ROOT")}
INDEX="$ROOT/.prototype/keys"
FALLBACK_FILE="$ROOT/.env.local"
ACCOUNT=${USER:-${USERNAME:-prototype}}
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

valid_name() { [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "invalid key name: $1"; }
service() { printf 'prototype:%s:%s' "$PROJECT" "$1"; }
to_hex() { od -An -v -tx1 | tr -d ' \n'; }
from_hex() { tr -d '\r\n' | perl -ne 'print pack("H*", $_)'; }

# Pick the store for this OS. PROTOTYPE_SECRETS_BACKEND overrides (keychain|wincred|secret-tool|file).
backend() {
  if [[ -n "${PROTOTYPE_SECRETS_BACKEND:-}" ]]; then echo "$PROTOTYPE_SECRETS_BACKEND"; return; fi
  case "$(uname -s)" in
    Darwin) if command -v security >/dev/null 2>&1; then echo keychain; return; fi ;;
    MINGW*|MSYS*|CYGWIN*) if command -v powershell.exe >/dev/null 2>&1; then echo wincred; return; fi ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null && command -v powershell.exe >/dev/null 2>&1; then echo wincred; return; fi
      if command -v secret-tool >/dev/null 2>&1 && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then echo secret-tool; return; fi ;;
  esac
  echo file
}
BACKEND=$(backend)

store_label() {
  case "$BACKEND" in
    keychain) echo "your macOS Keychain" ;;
    wincred) echo "Windows Credential Manager" ;;
    secret-tool) echo "your system keyring (Secret Service)" ;;
    *) echo ".env.local (no credential store found on this system)" ;;
  esac
}

win_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"
  elif command -v wslpath >/dev/null 2>&1; then wslpath -w "$1"
  else echo "$1"; fi
}
# wincred OP NAME — hex value on stdin for "set", hex value on stdout for "get".
wincred() {
  powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass \
    -File "$(win_path "$SCRIPT_DIR/wincred.ps1")" "$1" "$(service "$2")"
}

vercel_bin() {
  if command -v vercel >/dev/null 2>&1; then echo vercel
  elif [[ -x "$ROOT/node_modules/.bin/vercel" ]]; then echo "$ROOT/node_modules/.bin/vercel"
  else echo "npx --yes vercel"; fi
}

# ---------- index (names only) ----------
index_names() { [[ -f "$INDEX" ]] && grep -E '^[A-Za-z_][A-Za-z0-9_]*$' "$INDEX" || true; }
index_add() {
  mkdir -p "$(dirname "$INDEX")"
  [[ -f "$INDEX" ]] || printf '# Key names for this prototype. Values live in your OS credential store.\n' >"$INDEX"
  grep -qx "$1" "$INDEX" || echo "$1" >>"$INDEX"
}
index_remove() {
  [[ -f "$INDEX" ]] || return 0
  local tmp; tmp=$(mktemp)
  grep -vx "$1" "$INDEX" >"$tmp" || true
  mv "$tmp" "$INDEX"
}

# ---------- storage backends ----------
# Values travel as hex on stdin (never as command arguments), so they don't
# appear in a process list and quoting can't break them. Multi-line values are
# stored base64-encoded with a "b64:" prefix.
store_hex() { # NAME HEX
  local name=$1 hex=$2
  case "$BACKEND" in
    keychain)
      printf 'add-generic-password -U -a "%s" -s "%s" -l "%s" -j "%s" -X %s\n' \
        "$ACCOUNT" "$(service "$name")" "$(service "$name")" "Managed by the setup-prototype-project skill" "$hex" \
        | security -i >/dev/null
      has_value "$name" || die "Keychain did not accept $name" ;;
    wincred)
      printf '%s' "$hex" | wincred set "$name" >/dev/null || die "Credential Manager did not accept $name" ;;
    secret-tool)
      printf '%s' "$hex" | from_hex \
        | secret-tool store --label="$(service "$name")" service prototype project "$PROJECT" name "$name" \
        || die "the system keyring did not accept $name" ;;
    *)
      local value tmp; value=$(printf '%s' "$hex" | from_hex)
      [[ "$value" != *'"'* ]] || die "values containing \" are not supported in the .env.local fallback"
      touch "$FALLBACK_FILE"; chmod 600 "$FALLBACK_FILE"
      tmp=$(mktemp)
      grep -v "^$name=" "$FALLBACK_FILE" >"$tmp" || true
      printf '%s="%s"\n' "$name" "$value" >>"$tmp"
      mv "$tmp" "$FALLBACK_FILE"; chmod 600 "$FALLBACK_FILE" ;;
  esac
  index_add "$name"
}

store_value() { # NAME VALUE
  local name=$1 value=$2
  [[ -n "$value" ]] || die "empty value for $name"
  if [[ "$value" == *$'\n'* ]]; then value="b64:$(printf '%s' "$value" | base64 | tr -d '\n')"; fi
  store_hex "$name" "$(printf '%s' "$value" | to_hex)"
}

read_value() { # NAME -> stdout (internal use only; never echo to the person)
  local name=$1 raw
  case "$BACKEND" in
    keychain) raw=$(security find-generic-password -a "$ACCOUNT" -s "$(service "$name")" -w 2>/dev/null) || return 1 ;;
    wincred) raw=$(wincred get "$name" </dev/null 2>/dev/null | from_hex) || return 1 ;;
    secret-tool) raw=$(secret-tool lookup service prototype project "$PROJECT" name "$name" 2>/dev/null) || return 1 ;;
    *)
      [[ -f "$FALLBACK_FILE" ]] || return 1
      raw=$(grep "^$name=" "$FALLBACK_FILE" | tail -1 | sed -E 's/^[^=]+="?//; s/"$//') || return 1 ;;
  esac
  [[ -n "$raw" ]] || return 1
  if [[ "$raw" == b64:* ]]; then printf '%s' "${raw#b64:}" | base64 --decode; else printf '%s' "$raw"; fi
}

has_value() {
  case "$BACKEND" in
    keychain) security find-generic-password -a "$ACCOUNT" -s "$(service "$1")" >/dev/null 2>&1 ;;
    wincred) wincred has "$1" </dev/null >/dev/null 2>&1 ;;
    secret-tool) [[ -n "$(secret-tool lookup service prototype project "$PROJECT" name "$1" 2>/dev/null)" ]] ;;
    *) [[ -f "$FALLBACK_FILE" ]] && grep -q "^$1=" "$FALLBACK_FILE" ;;
  esac
}

delete_value() {
  case "$BACKEND" in
    keychain) security delete-generic-password -a "$ACCOUNT" -s "$(service "$1")" >/dev/null 2>&1 || true ;;
    wincred) wincred del "$1" </dev/null >/dev/null 2>&1 || true ;;
    secret-tool) secret-tool clear service prototype project "$PROJECT" name "$1" 2>/dev/null || true ;;
    *)
      if [[ -f "$FALLBACK_FILE" ]]; then
        local tmp; tmp=$(mktemp); grep -v "^$1=" "$FALLBACK_FILE" >"$tmp" || true; mv "$tmp" "$FALLBACK_FILE"
      fi ;;
  esac
  index_remove "$1"
}

# Ask the person for a value in an on-screen dialog with a hidden field; value on stdout.
# Returns non-zero if cancelled or no dialog is available.
win_prompt() { # NAME HINT
  local name=${1//\'/\'\'} hint=${2//\'/\'\'}
  powershell.exe -NoProfile -Command "\$c = Get-Credential -UserName '$name' -Message '$hint'; if (\$c -and \$c.GetNetworkCredential().Password) { [Console]::Out.Write(([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes(\$c.GetNetworkCredential().Password)) -replace '-','')) } else { exit 1 }" </dev/null \
    | from_hex
}
ask_dialog() { # NAME HINT
  local name=$1 hint=$2
  case "$(uname -s)" in
    Darwin)
      osascript - "$name" "$hint" 2>/dev/null <<'OSA'
on run argv
  set r to display dialog (item 2 of argv) default answer "" with hidden answer with title ("Save " & (item 1 of argv)) buttons {"Cancel", "Save"} default button "Save" cancel button "Cancel" with icon note
  return text returned of r
end run
OSA
      ;;
    MINGW*|MSYS*|CYGWIN*) win_prompt "$name" "$hint" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null && command -v powershell.exe >/dev/null 2>&1; then
        win_prompt "$name" "$hint"
      elif [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && command -v zenity >/dev/null 2>&1; then
        zenity --entry --hide-text --title="Save $name" --text="$hint" 2>/dev/null
      elif [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && command -v kdialog >/dev/null 2>&1; then
        kdialog --title "Save $name" --password "$hint" 2>/dev/null
      else return 1; fi ;;
    *) return 1 ;;
  esac
}

# Parse a dotenv file into "NAME<TAB>HEX" lines (multi-line values get the b64: prefix).
dotenv_to_hex() { # FILE [skip-regex]
  node - "$1" "${2:-^$}" <<'NODE'
const fs = require("fs");
const [file, skip] = process.argv.slice(2);
const skipRe = new RegExp(skip);
for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
  const m = line.match(/^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/);
  if (!m || skipRe.test(m[1])) continue;
  let v = m[2].trim();
  if (v.startsWith('"') && v.endsWith('"') && v.length >= 2) {
    v = v.slice(1, -1).replace(/\\n/g, "\n").replace(/\\r/g, "\r").replace(/\\"/g, '"').replace(/\\\\/g, "\\");
  } else if (v.startsWith("'") && v.endsWith("'") && v.length >= 2) {
    v = v.slice(1, -1);
  } else {
    v = v.replace(/\s+#.*$/, "");
  }
  if (v.includes("\n")) v = "b64:" + Buffer.from(v).toString("base64");
  process.stdout.write(`${m[1]}\t${Buffer.from(v).toString("hex")}\n`);
}
NODE
}

require_linked() {
  [[ -f "$ROOT/.vercel/project.json" ]] || die "this folder isn't linked to Vercel yet. Run: vercel link --yes --project <name>"
}

# Pull one environment's variables to a private temp file; prints the path.
pull_to_temp() { # ENV
  local tmp; tmp=$(mktemp "${TMPDIR:-/tmp}/proto-env.XXXXXX")
  chmod 600 "$tmp"
  # shellcheck disable=SC2046
  if ! $(vercel_bin) env pull "$tmp" --environment="$1" --yes >/dev/null 2>&1; then
    rm -f "$tmp"; die "vercel env pull failed for '$1' (are you logged in and linked?)"
  fi
  echo "$tmp"
}

SYSTEM_VARS='^(VERCEL|TURBO|NX)_|^VERCEL$'

# ---------- commands ----------
cmd=${1:-help}; shift || true
case "$cmd" in
  ask)
    name=${1:-}; [[ -n "$name" ]] || die "usage: ask NAME [HINT]"; valid_name "$name"
    hint=${2:-"Paste the value for $name, then click Save."}
    value=$(ask_dialog "$name" "$hint") || die "nothing saved for $name (dialog cancelled, or no dialog available here; use 'set NAME' in a visible terminal)"
    [[ -n "$value" ]] || die "nothing saved for $name (empty value)"
    store_value "$name" "$value"
    echo "Saved $name to $(store_label) for '$PROJECT'."
    ;;

  set)
    name=${1:-}; [[ -n "$name" ]] || die "usage: set NAME [--stdin]"; valid_name "$name"
    if [[ "${2:-}" == "--stdin" ]]; then
      value=$(cat)
    else
      [[ -t 0 ]] || die "no interactive terminal: use 'ask NAME' (on-screen dialog) or pipe a value with --stdin"
      read -r -s -p "Paste the value for $name (hidden), then press Enter: " value; echo
    fi
    store_value "$name" "$value"
    echo "Saved $name to $(store_label) for '$PROJECT'."
    ;;

  list)
    names=$(index_names)
    [[ -n "$names" ]] || { echo "No keys stored for '$PROJECT' yet."; exit 0; }
    echo "Keys for '$PROJECT':"
    while read -r n; do
      if has_value "$n"; then echo "  ✓ $n"; else echo "  ✗ $n (listed but missing — run: secrets.sh set $n)"; fi
    done <<<"$names"
    ;;

  has)
    valid_name "${1:-}"; has_value "$1"
    ;;

  remove)
    valid_name "${1:-}"; delete_value "$1"; echo "Removed $1."
    ;;

  run)
    [[ "${1:-}" == "--" ]] && shift
    [[ $# -gt 0 ]] || die "usage: run -- CMD..."
    while read -r n; do
      [[ -n "$n" ]] || continue
      if v=$(read_value "$n"); then export "$n=$v"; else echo "secrets: warning, $n is listed but not stored" >&2; fi
    done <<<"$(index_names)"
    exec "$@"
    ;;

  write-env)
    file="$ROOT/${1:-.env.local}"
    if git -C "$ROOT" rev-parse >/dev/null 2>&1 && ! git -C "$ROOT" check-ignore -q "$file"; then
      echo "$(basename "$file")" >>"$ROOT/.gitignore"; echo "Added $(basename "$file") to .gitignore."
    fi
    ( umask 077
      : >"$file"
      while read -r n; do
        [[ -n "$n" ]] || continue
        v=$(read_value "$n") || continue
        # Matches how Next.js reads env files: "$" would expand, newlines need \n.
        v=${v//\$/\\\$}; v=${v//$'\n'/\\n}
        printf '%s="%s"\n' "$n" "$v" >>"$file"
      done <<<"$(index_names)" )
    echo "Wrote $(index_names | grep -c . || true) key(s) to $(basename "$file") (owner-only, git-ignored). Prefer 'run' when you can."
    ;;

  import-env)
    file=${1:-}; [[ -f "$file" ]] || die "usage: import-env FILE"
    count=0
    while IFS=$'\t' read -r n hex; do
      [[ -n "$n" && -n "$hex" ]] || continue
      store_hex "$n" "$hex"; echo "  stored $n"; count=$((count + 1))
    done <<<"$(dotenv_to_hex "$file")"
    echo "Imported $count key(s). You can now delete $file."
    ;;

  push-vercel)
    name=${1:-}; valid_name "$name"; shift
    require_linked
    plain=false; envs=()
    for a in "$@"; do if [[ "$a" == "--plain" ]]; then plain=true; else envs+=("$a"); fi; done
    [[ ${#envs[@]} -gt 0 ]] || envs=(production preview development)
    value=$(read_value "$name") || die "$name isn't stored locally. Run: secrets.sh set $name"
    for env in "${envs[@]}"; do
      flags=(--force --yes)
      if [[ "$plain" == false && "$env" != "development" ]]; then flags+=(--sensitive); fi
      # shellcheck disable=SC2046
      if printf '%s' "$value" | $(vercel_bin) env add "$name" "$env" "${flags[@]}" >/dev/null 2>&1; then
        echo "  ✓ $name → Vercel $env"
      else
        echo "  ✗ $name → Vercel $env failed. Try updating the CLI (npm i -g vercel@latest), or run 'vercel env add $name $env' in a terminal the person can see." >&2
      fi
    done
    ;;

  pull-vercel)
    env=${1:-development}
    require_linked
    tmp=$(pull_to_temp "$env"); trap 'rm -f "$tmp"' EXIT
    added=0; skipped=()
    while IFS=$'\t' read -r n hex; do
      [[ -n "$n" ]] || continue
      if [[ -z "$hex" ]]; then skipped+=("$n"); continue; fi
      store_hex "$n" "$hex"; echo "  ✓ $n"; added=$((added + 1))
    done <<<"$(dotenv_to_hex "$tmp" "$SYSTEM_VARS")"
    echo "Captured $added key(s) from Vercel $env into local storage."
    [[ ${#skipped[@]} -eq 0 ]] || echo "Skipped (empty or sensitive on Vercel; get these from the provider): ${skipped[*]}"
    ;;

  diff-vercel)
    require_linked
    declare_names() { cut -f1 <<<"$(dotenv_to_hex "$1" "$SYSTEM_VARS")"; }
    prod=$(pull_to_temp production); prev=$(pull_to_temp preview); dev=$(pull_to_temp development)
    trap 'rm -f "$prod" "$prev" "$dev"' EXIT
    p=$(declare_names "$prod"); r=$(declare_names "$prev"); d=$(declare_names "$dev")
    all=$( { index_names; echo "$p"; echo "$r"; echo "$d"; } | grep -E . | sort -u || true)
    [[ -n "$all" ]] || { echo "No keys locally or on Vercel."; exit 0; }
    mark() { grep -qx "$1" <<<"$2" && echo "yes" || echo "-"; }
    printf '%-36s %-6s %-11s %-8s %-11s\n' NAME local production preview development
    while read -r n; do
      l=$(has_value "$n" && echo "yes" || echo "-")
      printf '%-36s %-6s %-11s %-8s %-11s\n' "$n" "$l" "$(mark "$n" "$p")" "$(mark "$n" "$r")" "$(mark "$n" "$d")"
    done <<<"$all"
    echo "Fix gaps with: push-vercel NAME (local → Vercel) or pull-vercel ENV (Vercel → local)."
    ;;

  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
