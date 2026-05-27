#!/bin/bash
# Public-safe bootstrap for:
#   curl -fsSL https://<domain>/mantis/install | bash
#
# This script intentionally contains no private key or license secret. It only
# installs prerequisites needed to clone the private runtime repo, then delegates
# to install-linux.sh inside that repo.
set -euo pipefail

REPO_SSH="${MANTIS_REPO_SSH:-git@github.com-mantis:CalebDane7/mantis-ai-controller-private.git}"
REPO_DIR="${MANTIS_REPO_DIR:-$HOME/.ai-controller-repo}"
KEY_DEST="${MANTIS_DEPLOY_KEY_DEST:-$HOME/.ssh/mantis-ai-controller-deploy-key}"
DEPLOY_KEY_FILE=""
NONINTERACTIVE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO_SSH="$2"; shift 2 ;;
    --repo-dir) REPO_DIR="$2"; shift 2 ;;
    --deploy-key) DEPLOY_KEY_FILE="$2"; shift 2 ;;
    --noninteractive) NONINTERACTIVE=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

have() {
  command -v "$1" >/dev/null 2>&1
}

if ! have git || ! have ssh; then
  if have apt-get; then
    sudo apt-get update -qq 2>/dev/null || true
    sudo apt-get install -y -qq git openssh-client ca-certificates curl >/dev/null
  else
    echo "git and ssh are required before running the Mantis installer." >&2
    exit 1
  fi
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

backup_existing_key() {
  [ -f "$KEY_DEST" ] || return 0
  backup="$KEY_DEST.backup-$(date +%Y%m%d-%H%M%S)"
  cp -a "$KEY_DEST" "$backup"
  chmod 600 "$backup"
}

if [ -n "${MANTIS_DEPLOY_KEY:-}" ]; then
  backup_existing_key
  printf '%s\n' "$MANTIS_DEPLOY_KEY" > "$KEY_DEST"
  chmod 600 "$KEY_DEST"
elif [ -n "$DEPLOY_KEY_FILE" ]; then
  backup_existing_key
  install -m 0600 "$DEPLOY_KEY_FILE" "$KEY_DEST"
elif [ ! -f "$KEY_DEST" ]; then
  if [ "$NONINTERACTIVE" = "1" ]; then
    echo "missing deploy key: set MANTIS_DEPLOY_KEY or pass --deploy-key" >&2
    exit 1
  fi
  if [ ! -r /dev/tty ]; then
    echo "missing deploy key: pass --deploy-key or set MANTIS_DEPLOY_KEY; no tty available for paste" >&2
    exit 1
  fi
  echo "Paste Mantis deploy key, then press Ctrl-D:" >/dev/tty
  cat /dev/tty > "$KEY_DEST"
  chmod 600 "$KEY_DEST"
fi

SSHCFG="$HOME/.ssh/config"
if ! grep -q "Host github.com-mantis" "$SSHCFG" 2>/dev/null; then
  cat >> "$SSHCFG" <<SSHEOF

Host github.com-mantis
  HostName github.com
  User git
  IdentityFile $KEY_DEST
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
SSHEOF
fi
chmod 600 "$SSHCFG"

if [ ! -d "$REPO_DIR/.git" ]; then
  git clone "$REPO_SSH" "$REPO_DIR"
else
  git -C "$REPO_DIR" pull --quiet
fi

exec bash "$REPO_DIR/install/install-linux.sh" --repo-dir "$REPO_DIR" --deploy-key "$KEY_DEST" --noninteractive
