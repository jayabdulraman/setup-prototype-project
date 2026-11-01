#!/usr/bin/env bash
# discover.sh — first-pass lookup for a new tool: is there a CLI, package, skill, or integration?
# Usage: bash discover.sh <tool-or-vendor>   e.g. stripe, resend, openai, google-calendar
# Results are leads, not verdicts: confirm with the vendor's own docs before proposing an install.
set -uo pipefail

q=${1:-}; [[ -n "$q" ]] || { echo "usage: discover.sh <tool-or-vendor>" >&2; exit 1; }
limit() { local s=$1; shift; ( perl -e 'alarm shift @ARGV; exec @ARGV' "$s" "$@" </dev/null ) 2>/dev/null; }
strip() { sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g'; }
section() { printf '\n== %s ==\n' "$1"; }

section "Already on this machine"
if command -v "$q" >/dev/null; then echo "$q: $(command -v "$q") ($("$q" --version 2>/dev/null | head -1))"; else echo "no '$q' command found"; fi

section "Homebrew"
if command -v brew >/dev/null; then
  export HOMEBREW_NO_AUTO_UPDATE=1
  for f in "$q" "$q-cli" "$q/tap/$q" "$q/$q/$q"; do
    info=$(limit 20 brew info --json=v2 "$f" | jq -r '(.formulae + .casks)[0] | select(.) | "\(.full_name // .full_token) — \(.desc) — \(.homepage)"' 2>/dev/null)
    [[ -n "$info" ]] && echo "$info  →  brew install $f"
  done
  limit 20 brew search "$q" | grep -E '^[a-z0-9@]' | head -6 | sed 's/^/  search: /'
else echo "Homebrew not installed"; fi

if command -v winget >/dev/null 2>&1 || command -v winget.exe >/dev/null 2>&1; then
  section "winget (Windows)"
  limit 30 winget search --source winget --disable-interactivity "$q" | strip | grep -v '^[[:space:]]*$' | head -8 || echo "lookup unavailable"
  echo "  install: winget install -e --id <Id>"
fi
if command -v scoop >/dev/null 2>&1; then
  section "Scoop (Windows)"
  limit 30 scoop search "$q" | strip | grep -v '^[[:space:]]*$' | head -8 || echo "lookup unavailable"
fi

section "npm packages"
for p in "$q" "@$q/cli" "$q-cli" "@$q/$q" "@$q/sdk"; do
  out=$(limit 15 npm view "$p" name version description repository.url --json 2>/dev/null)
  if [[ -n "$out" && "$out" != *'"error"'* ]]; then
    jq -r '"\(.name)@\(.version) — \(.description // "") — \(.["repository.url"] // "")"' <<<"$out" 2>/dev/null
  fi
done
limit 20 npm search "$q" --json 2>/dev/null | jq -r '.[:6][] | "  search: \(.name) — \(.publisher.username // "?") — \(.description // "" | .[0:80])"' 2>/dev/null

section "Agent skills (skills.sh)"
out=$(limit 30 npx --yes skills find "$q" | strip | grep -v '^[[:space:]]*$')
[[ -n "$out" ]] && head -12 <<<"$out" || echo "lookup unavailable"
echo "  install: npx skills add <owner/repo> -g -y   (project level: drop -g)"

section "Vercel Marketplace"
if command -v vercel >/dev/null; then
  out=$(limit 30 vercel integration discover "$q" | strip | grep -v '^[[:space:]]*$')
  if [[ -n "$out" && "$out" != *"Error:"* ]]; then head -12 <<<"$out"; else echo "lookup unavailable (offline or not logged in)"; fi
  echo "  install: vercel integration add <name>   (needs a linked project)"
else echo "vercel CLI not installed"; fi

section "Next: confirm with the vendor"
echo "Search the web for: \"$q official CLI\", \"$q agent skill\", \"$q MCP server\", \"$q Next.js quickstart\"."
echo "Prefer packages and skills published by the vendor's own GitHub org or npm scope."
echo "Install the latest stable release (npm: @latest; never canary/beta unless asked)."
