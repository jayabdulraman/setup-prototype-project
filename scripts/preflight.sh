#!/usr/bin/env bash
# preflight.sh — what's installed, what's missing, and what's behind the latest stable release.
# Usage: bash preflight.sh [target-dir]
# Output: one line per check, "STATUS  item  detail".
#   OK, MISSING, OUTDATED (installed < latest stable), WARN, INFO.
# Works on macOS, Windows (Git Bash) and Linux. Checks are listed in install order.
set -uo pipefail

TARGET=${1:-}
line() { printf '%-9s %-18s %s\n' "$1" "$2" "$3"; }
have() { command -v "$1" >/dev/null 2>&1; }

# Run a command with a time limit (macOS and Git Bash have no `timeout`).
limit() { local s=$1; shift; ( perl -e 'alarm shift @ARGV; exec @ARGV' "$s" "$@" </dev/null ) 2>/dev/null; }

semver() { grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' <<<"$1" | head -1; }
# ver_lt A B: true when A is older than B
ver_lt() { [[ -n "$1" && -n "$2" && "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$1" ]]; }

case "$(uname -s)" in
  Darwin) OS=mac; OS_NAME="macOS $(sw_vers -productVersion 2>/dev/null)" ;;
  MINGW*|MSYS*|CYGWIN*) OS=windows; OS_NAME="Windows (Git Bash)" ;;
  Linux) if grep -qi microsoft /proc/version 2>/dev/null; then OS=wsl; OS_NAME="Linux on WSL"; else OS=linux; OS_NAME="Linux"; fi ;;
  *) OS=other; OS_NAME=$(uname -s) ;;
esac
have nvm || [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]] && USES_NVM=1 || USES_NVM=0

# How to install or upgrade a tool on this OS.
how() { # ACTION(install|upgrade) TOOL
  local a=$1 t=$2
  case "$OS:$t" in
    *:vercel) echo "npm i -g vercel@latest" ;;
    mac:node|linux:node|wsl:node)
      if (( USES_NVM )); then echo "nvm install --lts && nvm alias default 'lts/*'"
      elif [[ $OS == mac ]]; then [[ $a == install ]] && echo "brew install node" || echo "brew upgrade node"
      else echo "install nvm, then: nvm install --lts"; fi ;;
    windows:node) [[ $a == install ]] && echo "winget install -e --id OpenJS.NodeJS.LTS" || echo "winget upgrade -e --id OpenJS.NodeJS.LTS" ;;
    windows:git) echo "winget install -e --id Git.Git" ;;
    mac:git) echo "xcode-select --install" ;;
    windows:gh) [[ $a == install ]] && echo "winget install -e --id GitHub.cli" || echo "winget upgrade -e --id GitHub.cli" ;;
    *:gh) [[ $a == install ]] && echo "brew install gh" || echo "brew upgrade gh" ;;
    windows:supabase) [[ $a == install ]] && echo "scoop bucket add supabase https://github.com/supabase/scoop-bucket.git && scoop install supabase" || echo "scoop update supabase" ;;
    *:supabase) [[ $a == install ]] && echo "brew install supabase/tap/supabase" || echo "brew upgrade supabase" ;;
    windows:jq) echo "winget install -e --id jqlang.jq" ;;
    *:jq) echo "brew install jq (or your distro's package)" ;;
    *) echo "see 1-setup.md" ;;
  esac
}

# Latest stable versions (blank when offline; the caller then skips the comparison).
latest_npm() { limit 20 npm view "$1" version; }
latest_node_lts() {
  limit 20 curl -fsSL https://nodejs.org/dist/index.json \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s).find(v=>v.lts);if(r)console.log(r.version.slice(1))})'
}
latest_github() { limit 20 curl -fsSL "https://api.github.com/repos/$1/releases/latest" | grep -Eo '"tag_name": *"[^"]+"' | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1; }

# Compare an installed version with the latest stable and print the line.
report() { # NAME INSTALLED LATEST TOOL
  local name=$1 cur=$2 new=$3 tool=$4
  if [[ -z "$cur" ]]; then line OK "$name" "installed"
  elif [[ -z "$new" ]]; then line OK "$name" "$cur (couldn't check latest; offline?)"
  elif ver_lt "$cur" "$new"; then line OUTDATED "$name" "$cur → latest stable $new: $(how upgrade "$tool")"
  else line OK "$name" "$cur (latest stable)"; fi
}

echo "Prototype preflight — $OS_NAME ($(uname -m))"
echo

# ---------- 1-2. build tools and package manager ----------
case $OS in
  mac)
    if xcode-select -p >/dev/null 2>&1; then line OK xcode-clt "Command Line Tools present"
    else line MISSING xcode-clt "needed by Homebrew and git: xcode-select --install (opens an installer the person clicks through)"; fi
    if have brew; then line OK brew "$(brew --version | head -1)"
    else line MISSING brew "package manager for CLIs: official installer at brew.sh (run in a visible terminal; asks for the password)"; fi ;;
  windows)
    if have winget || have winget.exe; then line OK winget "present"
    else line WARN winget "missing; install 'App Installer' from the Microsoft Store"; fi
    if have scoop; then line OK scoop "present (used for the Supabase CLI)"
    else line INFO scoop "not installed; needed only for a global Supabase CLI (PowerShell: irm get.scoop.sh | iex)"; fi ;;
  linux|wsl)
    if have brew; then line OK brew "$(brew --version | head -1)"; else line INFO brew "optional; CLIs can install via npm or distro packages"; fi ;;
esac

# ---------- 3. git ----------
if have git; then
  line OK git "$(git --version)"
  if [[ -n "$(git config --global user.name)" && -n "$(git config --global user.email)" ]]; then line OK git-identity "$(git config --global user.name)"
  else line WARN git-identity "no name/email set; commits will fail (git config --global user.name/user.email)"; fi
else line MISSING git "needed to scaffold and commit: $(how install git)"; fi

# ---------- 4. Node.js (needed by everything below) ----------
NEXT_NODE=$(have npm && limit 20 npm view next@latest engines.node)
need_node=$(semver "${NEXT_NODE:-}")
if have node; then
  cur=$(semver "$(node --version)"); lts=$(latest_node_lts)
  if [[ -n "$need_node" ]] && ver_lt "$cur" "$need_node"; then
    line OUTDATED node "$cur, but the latest Next.js needs $NEXT_NODE: $(how upgrade node)"
  else report node "$cur" "$lts" node; fi
  [[ -n "$need_node" ]] && line INFO next-needs "latest Next.js requires Node $NEXT_NODE"
  if have npm; then line OK npm "$(npm --version) (ships with Node)"; else line MISSING npm "reinstall Node.js"; fi
else
  line MISSING node "needed by Next.js, shadcn, Vercel CLI, Playwright: $(how install node)"
  line MISSING npm "comes with Node.js"
fi

if have npm; then
  prefix=$(npm prefix -g 2>/dev/null)
  if [[ -w "$prefix" || -w "$prefix/lib" ]]; then line OK npm-global "can install global packages ($prefix)"
  else line WARN npm-global "no write access to $prefix; use project-level installs (never sudo)"; fi
fi

# ---------- 5-8. CLIs ----------
if have vercel; then report vercel "$(semver "$(limit 15 vercel --version 2>&1)")" "$(latest_npm vercel)" vercel
else line MISSING vercel "deploys the live link: $(how install vercel)"; fi

if have supabase; then report supabase "$(semver "$(supabase --version 2>/dev/null)")" "$(latest_npm supabase)" supabase
else line MISSING supabase "database upgrade path (optional now): $(how install supabase)"; fi

if have gh; then report gh "$(semver "$(gh --version | head -1)")" "$(latest_github cli/cli)" gh
else line INFO gh "optional (GitHub backup and auto-deploys): $(how install gh)"; fi

if have jq; then line OK jq "$(jq --version)"; else line WARN jq "used by discover.sh and key piping: $(how install jq)"; fi
have perl || line WARN perl "used by secrets.sh and these checks"

# ---------- credential store ----------
case $OS in
  mac) have security && line OK keys "macOS Keychain" || line WARN keys "no Keychain; secrets.sh will use .env.local" ;;
  windows|wsl)
    if have powershell.exe; then line OK keys "Windows Credential Manager (via powershell.exe)"
    else line WARN keys "powershell.exe not reachable; secrets.sh will use .env.local"; fi ;;
  *)
    if have secret-tool && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then line OK keys "Secret Service (secret-tool)"
    else line WARN keys "no Secret Service; secrets.sh will use a git-ignored .env.local (install libsecret-tools for a keyring)"; fi ;;
esac

# ---------- browsers for testing ----------
case $OS in
  mac) pw="$HOME/Library/Caches/ms-playwright" ;;
  windows) pw="$(cygpath -u "${LOCALAPPDATA:-}" 2>/dev/null)/ms-playwright" ;;
  *) pw="$HOME/.cache/ms-playwright" ;;
esac
if ls "$pw" 2>/dev/null | grep -q chromium; then line OK playwright "Chromium downloaded"
else line INFO playwright "Chromium not downloaded yet (installed during setup)"; fi

# ---------- logins ----------
echo
if have vercel; then
  who=$(limit 20 vercel whoami 2>&1 | tail -1); rc=$?
  if [[ $rc -eq 0 && -n "$who" && "$who" != *"Logged out"* && "$who" != *"rror"* && "$who" != *"not logged"* ]]; then
    line OK vercel-login "$who"
  else line INFO vercel-login "not signed in (agent runs: vercel login)"; fi
fi
if have gh; then
  if limit 15 gh auth status >/dev/null; then line OK gh-login "logged in"; else line INFO gh-login "not signed in (agent runs: gh auth login --web)"; fi
fi
if have supabase; then
  if limit 20 supabase projects list >/dev/null; then line OK supabase-login "logged in"; else line INFO supabase-login "not signed in (optional; agent runs: supabase login)"; fi
fi

# ---------- folder ----------
if [[ -n "$TARGET" ]]; then
  echo
  abs=$(cd "$(dirname "$TARGET")" 2>/dev/null && echo "$(pwd)/$(basename "$TARGET")" || echo "$TARGET")
  case "$abs" in
    *"/Library/CloudStorage/"*|*"/Library/Mobile Documents/"*|*"/Dropbox"*|*"/OneDrive"*|*"/Google Drive"*|*"/iCloud"*)
      line INFO folder "cloud-synced folder; after scaffolding run ignore-sync.sh so Dropbox skips node_modules and build output" ;;
  esac
  if [[ -f "$abs/PROTOTYPE.md" ]]; then line INFO folder "existing prototype: resume from PROTOTYPE.md (and run npm outdated)"
  elif [[ -d "$abs" && -n "$(ls -A "$abs" 2>/dev/null)" ]]; then line WARN folder "$abs exists and is not empty"
  elif [[ -d "$abs" ]]; then line OK folder "$abs (empty)"
  else line OK folder "$abs (will be created)"; fi
fi
