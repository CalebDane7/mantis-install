#!/bin/bash
# Public-safe bootstrap for:
#   curl -fsSL https://<domain>/mantis/install | bash
#
# This script intentionally contains no private key or license secret.
# Default path remains the original deploy-key/git installer. The new
# server-authorized bundle path is explicit/opt-in and never writes ~/.ssh.
# WHY: this public entrypoint is copied straight into a Mac user's
# `curl ... | bash` flow, where `/bin/bash` is still 3.2. Bash 3.2 plus
# nounset has empty-array edge cases that previously broke the account-bound
# invite install before Mantis Remote could register, so keep this installer
# fail-fast without `set -u`.
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd -P 2>/dev/null || printf '.')"
if [ -f "$SCRIPT_DIR/platform-helpers.sh" ]; then
  # shellcheck source=install/platform-helpers.sh
  . "$SCRIPT_DIR/platform-helpers.sh"
else
  mantis_uname_s() { uname -s 2>/dev/null || printf '%s\n' unknown; }
  mantis_host_platform() {
    case "${MANTIS_PLATFORM_OVERRIDE:-}" in
      wsl|WSL) printf '%s\n' wsl; return 0 ;;
      linux|Linux) printf '%s\n' linux; return 0 ;;
      macos|darwin|Darwin) printf '%s\n' macos; return 0 ;;
    esac
    if [ -n "${WSL_DISTRO_NAME:-}" ] || { [ -r /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; } || [ -d /mnt/c/Windows ]; then
      printf '%s\n' wsl
    elif [ "$(mantis_uname_s)" = "Darwin" ]; then
      printf '%s\n' macos
    else
      printf '%s\n' linux
    fi
  }
fi

REPO_SSH="${MANTIS_REPO_SSH:-git@github.com-mantis:CalebDane7/mantis-ai-controller-private.git}"
REPO_DIR="${MANTIS_REPO_DIR:-$HOME/.ai-controller-repo}"
KEY_DEST="${MANTIS_DEPLOY_KEY_DEST:-$HOME/.ssh/mantis-ai-controller-deploy-key}"
DEPLOY_KEY_FILE=""
NONINTERACTIVE=0
INSTALL_SOURCE="${MANTIS_INSTALL_SOURCE:-}"

STATE_DIR="${MANTIS_STATE_DIR:-$HOME/.mantis}"
CONFIG_FILE="${MANTIS_CONFIG_FILE:-$STATE_DIR/config}"
RUNTIME_ROOT="${MANTIS_RUNTIME_ROOT:-$STATE_DIR/runtime}"
CONTROL_PLANE_URL="${MANTIS_CONTROL_PLANE_URL:-}"
BUNDLE_MANIFEST_URL="${MANTIS_BUNDLE_MANIFEST_URL:-}"
DEFAULT_CONTROL_PLANE_URL="${MANTIS_DEFAULT_CONTROL_PLANE_URL:-https://erebora.org/mantis}"
ACTIVATION_TOKEN="${MANTIS_ACTIVATION_TOKEN:-}"
INVITE="${MANTIS_INVITE:-}"
PHONE_SETUP="${MANTIS_PHONE_SETUP:-prompt}"
ROOT_ADMIN_SETUP="${MANTIS_ROOT_ADMIN_SETUP:-prompt}"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO_SSH="$2"; shift 2 ;;
    --repo-dir) REPO_DIR="$2"; shift 2 ;;
    --deploy-key) DEPLOY_KEY_FILE="$2"; shift 2 ;;
    --source) INSTALL_SOURCE="$2"; shift 2 ;;
    --control-plane-url) CONTROL_PLANE_URL="$2"; shift 2 ;;
    --bundle-manifest-url|--manifest-url) BUNDLE_MANIFEST_URL="$2"; shift 2 ;;
    --activation-token) ACTIVATION_TOKEN="$2"; shift 2 ;;
    --invite) INVITE="$2"; shift 2 ;;
    --setup-phone|--phone-setup) PHONE_SETUP="yes"; shift ;;
    --skip-phone|--skip-phone-setup) PHONE_SETUP="skip"; shift ;;
    --enable-root-admin|--setup-root-admin|--root-admin) ROOT_ADMIN_SETUP="yes"; shift ;;
    --skip-root-admin|--no-root-admin) ROOT_ADMIN_SETUP="skip"; shift ;;
    --noninteractive) NONINTERACTIVE=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

case "$PHONE_SETUP" in
  yes|prompt|skip) ;;
  *) echo "unknown phone setup mode: $PHONE_SETUP" >&2; exit 1 ;;
esac
case "$ROOT_ADMIN_SETUP" in
  yes|prompt|skip) ;;
  *) echo "unknown root-admin setup mode: $ROOT_ADMIN_SETUP" >&2; exit 1 ;;
esac

if [ -z "$INSTALL_SOURCE" ]; then
  if [ -n "$CONTROL_PLANE_URL$BUNDLE_MANIFEST_URL$ACTIVATION_TOKEN$INVITE" ]; then
    INSTALL_SOURCE="bundle"
  else
    INSTALL_SOURCE="git"
  fi
fi

have() {
  command -v "$1" >/dev/null 2>&1
}

dedupe_words() {
  awk '!seen[$0]++'
}

brew_package_for_cmd() {
  case "$1" in
    python3) echo python ;;
    sqlite3) echo sqlite ;;
    jq) echo jq ;;
    tmux) echo tmux ;;
    ttyd) echo ttyd ;;
    curl) echo curl ;;
    node|npm) echo node ;;
    git) echo git ;;
    ssh) echo openssh ;;
    *) return 1 ;;
  esac
}

add_homebrew_to_path() {
  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$candidate" ]; then
      eval "$("$candidate" shellenv)"
      return 0
    fi
  done
  return 1
}

ensure_macos_homebrew() {
  local missing_words="$1"
  local choice auto
  [ "$(mantis_host_platform)" = "macos" ] || return 1
  add_homebrew_to_path >/dev/null 2>&1 || true
  have brew && return 0
  auto="${MANTIS_AUTO_INSTALL_HOMEBREW:-prompt}"
  echo "Mantis needs Homebrew on stock macOS to install: $missing_words" >&2
  case "$auto" in
    1|yes|YES|true|TRUE) choice="yes" ;;
    0|no|NO|false|FALSE) choice="no" ;;
    *)
      if [ "$NONINTERACTIVE" = "1" ] || [ ! -r /dev/tty ]; then
        echo "Set MANTIS_AUTO_INSTALL_HOMEBREW=1 to let Mantis install Homebrew automatically, or install Homebrew first:" >&2
        echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
        return 1
      fi
      printf "Install Homebrew now using the official Homebrew installer? [y/N]: " >/dev/tty
      IFS= read -r choice </dev/tty || choice=""
      ;;
  esac
  case "$choice" in
    y|Y|yes|YES) ;;
    *) return 1 ;;
  esac
  # WHY: stock macOS lacks the Linux package manager Mantis uses elsewhere.
  # Homebrew's official installer is the supported way to add tmux/ttyd/node
  # from a single account-bound curl flow without inventing a private package
  # manager or asking the user to restart from separate manual instructions.
  if [ "$NONINTERACTIVE" = "1" ] || [ "$auto" = "1" ] || [ "$auto" = "yes" ]; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  add_homebrew_to_path >/dev/null 2>&1 || true
  have brew
}

install_deps() {
  local packages=()
  local missing=()
  local cmd pkg platform brew_packages="" missing_after=()
  for cmd in "$@"; do
    pkg="$cmd"
    case "$cmd" in
      ca-certificates|python3-pip|python3-venv|cron)
        packages+=("$pkg")
        continue
        ;;
      ssh) pkg="openssh-client" ;;
      crontab) pkg="cron" ;;
    esac
    packages+=("$pkg")
    have "$cmd" || missing+=("$cmd")
  done
  [ "${#missing[@]}" -eq 0 ] && return 0
  platform="$(mantis_host_platform)"
  case "$platform" in
    wsl|linux)
      if have apt-get; then
        if [ "$(id -u)" = "0" ]; then
          apt-get update -qq 2>/dev/null || true
          apt-get install -y -qq "${packages[@]}" >/dev/null
        elif have sudo; then
          sudo apt-get update -qq 2>/dev/null || true
          sudo apt-get install -y -qq "${packages[@]}" >/dev/null
        else
          echo "missing required commands: ${missing[*]}" >&2
          echo "apt-get is available, but sudo is not. Install packages as root, then rerun Mantis." >&2
          exit 1
        fi
      else
        echo "missing required commands: ${missing[*]}" >&2
        echo "No apt-get found; install these with this system's package manager, then rerun Mantis." >&2
        exit 1
      fi
      ;;
    macos)
      add_homebrew_to_path >/dev/null 2>&1 || true
      if ! have brew; then
        ensure_macos_homebrew "${missing[*]}" || {
          echo "missing required commands: ${missing[*]}" >&2
          echo "Homebrew is required on stock macOS so Mantis can install python3, tmux, ttyd, curl, and node/npm." >&2
          exit 1
        }
      fi
      if have brew; then
        for cmd in "${missing[@]}"; do
          if pkg="$(brew_package_for_cmd "$cmd")"; then
            case " $brew_packages " in
              *" $pkg "*) ;;
              *) brew_packages="${brew_packages:+$brew_packages }$pkg" ;;
            esac
          fi
        done
        if [ -n "$brew_packages" ]; then
          # WHY: macOS /bin/bash 3.2 with `set -u` can treat empty arrays as
          # unbound. Keep the public curl bootstrap on plain words here so a
          # stock Mac does not fail before the invite installs.
          brew install $brew_packages
        fi
      fi
      ;;
    *)
      echo "unsupported platform '$platform' with missing commands: ${missing[*]}" >&2
      exit 1
      ;;
  esac
  for cmd in "${missing[@]}"; do
    have "$cmd" || missing_after+=("$cmd")
  done
  if [ "${#missing_after[@]}" -gt 0 ]; then
    echo "still missing required commands after dependency install: ${missing_after[*]}" >&2
    exit 1
  fi
}

json_get() {
  local file="$1"
  local key="$2"
  python3 - "$file" "$key" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
value = data
for part in sys.argv[2].split("."):
    if isinstance(value, dict):
        value = value.get(part, "")
    else:
        value = ""
        break
if value is None:
    value = ""
print(value)
PY
}

curl_fetch() {
  local url="$1"
  local out="$2"
  case "$url" in
    file://*) cp "${url#file://}" "$out"; return ;;
    /*) cp "$url" "$out"; return ;;
  esac
  local args=(-fsSL)
  # WHY: native Mac networks may be IPv6-only or dual-stack. Do not force IPv4
  # unless the operator explicitly sets MANTIS_CURL_IP_MODE=ipv4.
  case "${MANTIS_CURL_IP_MODE:-auto}" in
    ipv4|4) args+=(-4) ;;
    ipv6|6) args+=(-6) ;;
    auto|"") ;;
    *) echo "invalid MANTIS_CURL_IP_MODE: $MANTIS_CURL_IP_MODE" >&2; return 2 ;;
  esac
  args+=(--connect-timeout "${MANTIS_CURL_CONNECT_TIMEOUT:-10}" --max-time "${MANTIS_CURL_MAX_TIME:-300}")
  [ -n "$ACTIVATION_TOKEN" ] && args+=(-H "Authorization: Bearer $ACTIVATION_TOKEN")
  [ -n "$INVITE" ] && args+=(-H "X-Mantis-Invite: $INVITE")
  curl "${args[@]}" "$url" -o "$out"
}

sha256_file() {
  local file="$1"
  if have sha256sum; then
    sha256sum "$file" | awk '{print $1}'
  elif have shasum; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    echo "sha256sum or shasum is required" >&2
    return 1
  fi
}

phone_install_args() {
  case "$PHONE_SETUP" in
    yes) printf '%s\n' "--setup-phone" ;;
    skip) printf '%s\n' "--skip-phone" ;;
    prompt) ;;
  esac
}

root_admin_install_args() {
  case "$ROOT_ADMIN_SETUP" in
    yes) printf '%s\n' "--enable-root-admin" ;;
    skip) printf '%s\n' "--skip-root-admin" ;;
    prompt) ;;
  esac
}

noninteractive_install_args() {
  if [ "$NONINTERACTIVE" = "1" ]; then
    printf '%s\n' "--noninteractive"
  fi
}

safe_tar_list() {
  local bundle="$1"
  local entry
  while IFS= read -r entry; do
    case "$entry" in
      ""|/*|*"/../"*|../*|*/..|..)
        echo "unsafe bundle path: $entry" >&2
        return 1
        ;;
    esac
  done < <(tar -tzf "$bundle")
}

write_config_key() {
  local key="$1"
  local value="$2"
  local tmp
  mkdir -p "$(dirname "$CONFIG_FILE")"
  tmp="${CONFIG_FILE}.tmp.$$"
  if [ -f "$CONFIG_FILE" ]; then
    awk -v key="$key" -v value="$value" '
      BEGIN { seen = 0 }
      $0 ~ "^" key "=" { print key "=" value; seen = 1; next }
      { print }
      END { if (!seen) print key "=" value }
    ' "$CONFIG_FILE" > "$tmp"
  else
    {
      echo "# Mantis local user config"
      echo "$key=$value"
    } > "$tmp"
  fi
  mv "$tmp" "$CONFIG_FILE"
}

write_auth() {
  [ -n "$ACTIVATION_TOKEN$INVITE" ] || return 0
  mkdir -p "$STATE_DIR"
  umask 077
  python3 - "$STATE_DIR/auth.json" "$ACTIVATION_TOKEN" "$INVITE" <<'PY'
import json, sys
path, token, invite = sys.argv[1:4]
data = {}
if token:
    data["activation_token"] = token
if invite:
    data["invite"] = invite
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, sort_keys=True)
    f.write("\n")
PY
  chmod 600 "$STATE_DIR/auth.json"
}

resolve_relative_bundle_url() {
  local manifest_url="$1"
  local bundle_url="$2"
  case "$bundle_url" in
    http://*|https://*|file://*|/*) printf '%s\n' "$bundle_url" ;;
    *)
      case "$manifest_url" in
        http://*|https://*) printf '%s/%s\n' "${manifest_url%/*}" "$bundle_url" ;;
        file://*) printf 'file://%s/%s\n' "$(dirname "${manifest_url#file://}")" "$bundle_url" ;;
        /*) printf '%s/%s\n' "$(dirname "$manifest_url")" "$bundle_url" ;;
        *) printf '%s\n' "$bundle_url" ;;
      esac
      ;;
  esac
}

bootstrap_bundle_install() {
  # WHY: the emailed Mantis Remote account link opens the registered web shell,
  # which frames a local ttyd terminal. Treat ttyd as a bootstrap dependency so
  # a fresh curl install cannot send a "ready" link that has no live terminal
  # transport behind it.
  install_deps python3 tar curl ca-certificates ttyd
  if [ -z "$BUNDLE_MANIFEST_URL$CONTROL_PLANE_URL" ] && [ -n "$ACTIVATION_TOKEN$INVITE" ]; then
    # WHY: Friend/beta setup is invite-based. If a user supplies only the
    # invite/token, default to the live control plane rather than failing with a
    # missing-manifest error.
    CONTROL_PLANE_URL="$DEFAULT_CONTROL_PLANE_URL"
  fi
  if [ -z "$BUNDLE_MANIFEST_URL" ] && [ -n "$CONTROL_PLANE_URL" ]; then
    BUNDLE_MANIFEST_URL="${CONTROL_PLANE_URL%/}/api/mantis/bundles/latest.json"
  fi
  [ -n "$BUNDLE_MANIFEST_URL" ] || {
    echo "missing bundle manifest URL; pass --bundle-manifest-url or --control-plane-url" >&2
    exit 1
  }

  mkdir -p "$STATE_DIR" "$RUNTIME_ROOT/releases"
  tmpdir="$(mktemp -d "$STATE_DIR/bootstrap-bundle.XXXXXX")"
  trap 'rm -rf "$tmpdir"' EXIT
  manifest="$tmpdir/latest.json"
  bundle="$tmpdir/mantis-bundle.tar.gz"
  curl_fetch "$BUNDLE_MANIFEST_URL" "$manifest"

  version="$(json_get "$manifest" version)"
  sha256="$(json_get "$manifest" sha256)"
  bundle_url="$(json_get "$manifest" url)"
  [ -n "$version" ] && [ -n "$sha256" ] && [ -n "$bundle_url" ] || {
    echo "bundle manifest must include version, sha256, and url" >&2
    exit 1
  }
  bundle_url="$(resolve_relative_bundle_url "$BUNDLE_MANIFEST_URL" "$bundle_url")"
  curl_fetch "$bundle_url" "$bundle"
  actual_sha="$(sha256_file "$bundle")"
  [ "$actual_sha" = "$sha256" ] || {
    echo "bundle checksum mismatch: expected $sha256 got $actual_sha" >&2
    exit 1
  }
  safe_tar_list "$bundle"

  release_id="$(printf '%s-%s' "$version" "${sha256:0:12}" | tr -c 'A-Za-z0-9._-' '-')"
  release_dir="$RUNTIME_ROOT/releases/$release_id"
  staging="$RUNTIME_ROOT/releases/.staging-$release_id-$$"
  rm -rf "$staging"
  mkdir -p "$staging"
  tar -xzf "$bundle" -C "$staging"
  [ -x "$staging/install/install-linux.sh" ] || chmod +x "$staging/install/install-linux.sh" 2>/dev/null || true
  [ -x "$staging/install/install-linux.sh" ] || {
    echo "bundle missing executable install/install-linux.sh" >&2
    exit 1
  }
  [ -f "$staging/ai-controller/bin/mantis" ] || {
    echo "bundle missing ai-controller/bin/mantis" >&2
    exit 1
  }

  cp "$manifest" "$staging/.mantis-bundle-manifest.json"
  rm -rf "$release_dir"
  mv "$staging" "$release_dir"
  rm -f "$RUNTIME_ROOT/current.next"
  ln -s "$release_dir" "$RUNTIME_ROOT/current.next"
  rm -f "$RUNTIME_ROOT/current"
  mv "$RUNTIME_ROOT/current.next" "$RUNTIME_ROOT/current"
  cp "$manifest" "$STATE_DIR/bundle-current.json"

  write_config_key install_source bundle
  write_config_key runtime_root "$RUNTIME_ROOT"
  write_config_key host_platform "$(mantis_host_platform)"
  write_config_key bundle_manifest_url "$BUNDLE_MANIFEST_URL"
  [ -n "$CONTROL_PLANE_URL" ] && write_config_key control_plane_url "$CONTROL_PLANE_URL"
  write_auth

  # WHY: the public website command pipes into macOS /bin/bash 3.2. Bash 3.2
  # under `set -u` can throw on empty optional arrays, so optional install args
  # are emitted as plain words instead of empty array expansions.
  exec bash "$RUNTIME_ROOT/current/install/install-linux.sh" \
    --source bundle \
    --repo-dir "$RUNTIME_ROOT/current" \
    --runtime-root "$RUNTIME_ROOT" \
    --bundle-manifest-url "$BUNDLE_MANIFEST_URL" \
    $(noninteractive_install_args) \
    $(root_admin_install_args) \
    $(phone_install_args)
}

bootstrap_git_install() {
  install_deps git ssh curl ca-certificates

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

  # WHY: keep the legacy deploy-key path usable from macOS /bin/bash 3.2 too;
  # the public invite flow and old private Git flow share this bootstrap file.
  exec bash "$REPO_DIR/install/install-linux.sh" --source git --repo-dir "$REPO_DIR" --deploy-key "$KEY_DEST" \
    $(noninteractive_install_args) \
    $(root_admin_install_args) \
    $(phone_install_args)
}

case "$INSTALL_SOURCE" in
  bundle) bootstrap_bundle_install ;;
  git) bootstrap_git_install ;;
  *) echo "unknown install source: $INSTALL_SOURCE" >&2; exit 1 ;;
esac
