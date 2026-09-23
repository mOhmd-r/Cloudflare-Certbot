#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly CERTBOT_BIN="/usr/bin/certbot"
readonly CONFIG_DIR="/etc/letsencrypt/cloudflare"
readonly CREDENTIALS_FILE="$CONFIG_DIR/credentials.ini"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  sudo ./certbot-cloudflare.sh --email EMAIL -d DOMAIN [-d DOMAIN ...]
                                [--credentials-file FILE]
                                [--propagation-seconds N]
                                [--install-dependencies] [--staging]

Required:
  --email EMAIL             ACME account email address.
  -d, --domain DOMAIN       Certificate identifier; repeat for SANs/wildcards.

Options:
  --credentials-file FILE   Import a private Cloudflare token INI file.
  --propagation-seconds N   DNS wait time from 10 to 3600 (default: 60).
  --install-dependencies    Install Ubuntu/Debian Certbot packages with apt.
  --staging                 Use Let's Encrypt's staging environment.
  -h, --help                Show this help.

The API token is never accepted as a command-line argument. If the protected
credentials file does not exist, the script prompts for it without echo.
USAGE
}

validate_dns_name() {
  local value=${1,,}
  local label
  local -a labels=()

  value=${value#\*.}
  [[ ${#value} -le 253 && $value != *..* ]] || return 1
  IFS='.' read -r -a labels <<<"$value"
  ((${#labels[@]} >= 2)) || return 1
  for label in "${labels[@]}"; do
    [[ ${#label} -le 63 ]] || return 1
    [[ $label =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || return 1
  done
}

validate_token() {
  [[ -n $1 && $1 =~ ^[A-Za-z0-9._~-]+$ ]]
}

read_token_file() {
  local source_file=$1
  local owner mode line
  local -a credential_lines=()

  [[ -f $source_file && ! -L $source_file ]] ||
    die "Credentials source must be a regular, non-symlink file"

  owner=$(stat -c '%u' "$source_file") ||
    die "Unable to inspect credentials owner"
  mode=$(stat -c '%a' "$source_file") ||
    die "Unable to inspect credentials permissions"
  [[ $owner == 0 && $mode =~ ^[0-7]{3,4}$ ]] ||
    die "Credentials source must be owned by root"
  local mode_decimal=$((8#$mode))
  (( (mode_decimal & 077) == 0 )) ||
    die "Credentials source must not be accessible by group or others"

  mapfile -t credential_lines < <(
    sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$source_file"
  )
  ((${#credential_lines[@]} == 1)) ||
    die "Credentials file must contain exactly one non-comment setting"

  line=${credential_lines[0]}
  [[ $line =~ ^[[:space:]]*dns_cloudflare_api_token[[:space:]]*=[[:space:]]*([^[:space:]]+)[[:space:]]*$ ]] ||
    die "Only dns_cloudflare_api_token is permitted in the credentials file"
  CLOUDFLARE_TOKEN=${BASH_REMATCH[1]}
  validate_token "$CLOUDFLARE_TOKEN" ||
    die "Cloudflare API token contains unsupported characters"
}

write_credentials() (
  set -Eeuo pipefail
  local token=$1
  local credentials_tmp

  validate_token "$token" || die "Cloudflare API token is invalid"
  credentials_tmp=$(mktemp "$CONFIG_DIR/.credentials.XXXXXX")
  trap 'rm -f -- "${credentials_tmp:-}"' EXIT
  printf '# Restricted Cloudflare API token used by Certbot\n' >"$credentials_tmp"
  printf 'dns_cloudflare_api_token = %s\n' "$token" >>"$credentials_tmp"
  install -o root -g root -m 0600 "$credentials_tmp" "$CREDENTIALS_FILE"
)

main() {
  local email=""
  local credentials_source=""
  local propagation_seconds=60
  local install_dependencies=false
  local staging=false
  local domain command_name credentials_owner credentials_mode plugins
  local -a domains=()
  local -a certbot_args=()

  while (($# > 0)); do
    case "$1" in
      --email)
        (($# >= 2)) || die "--email requires a value"
        email=$2
        shift 2
        ;;
      -d | --domain)
        (($# >= 2)) || die "$1 requires a value"
        domains+=("${2,,}")
        shift 2
        ;;
      --credentials-file)
        (($# >= 2)) || die "--credentials-file requires a value"
        credentials_source=$2
        shift 2
        ;;
      --propagation-seconds)
        (($# >= 2)) || die "--propagation-seconds requires a value"
        propagation_seconds=$2
        shift 2
        ;;
      --install-dependencies)
        install_dependencies=true
        shift
        ;;
      --staging)
        staging=true
        shift
        ;;
      -h | --help)
        usage
        return 0
        ;;
      *)
        die "Unknown argument: $1 (use --help)"
        ;;
    esac
  done

  ((EUID == 0)) || die "Run this script with sudo or as root"
  [[ -n $email ]] || die "--email is required"
  [[ $email =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] ||
    die "Invalid email address"
  ((${#domains[@]} > 0)) || die "At least one -d/--domain is required"
  [[ $propagation_seconds =~ ^[0-9]+$ ]] ||
    die "--propagation-seconds must be an integer"
  ((propagation_seconds >= 10 && propagation_seconds <= 3600)) ||
    die "--propagation-seconds must be between 10 and 3600"

  for domain in "${domains[@]}"; do
    validate_dns_name "$domain" || die "Invalid certificate identifier: $domain"
  done

  for command_name in grep install mktemp sed stat; do
    command -v "$command_name" >/dev/null 2>&1 ||
      die "Required command not found: $command_name"
  done

  if [[ $install_dependencies == true ]]; then
    command -v apt-get >/dev/null 2>&1 ||
      die "--install-dependencies requires apt-get"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      ca-certificates certbot python3-certbot-dns-cloudflare
  fi

  [[ -x $CERTBOT_BIN ]] ||
    die "System Certbot not found at $CERTBOT_BIN; use --install-dependencies"
  plugins=$("$CERTBOT_BIN" plugins --text 2>/dev/null) ||
    die "Unable to query Certbot plugins"
  grep -q 'dns-cloudflare' <<<"$plugins" ||
    die "Certbot Cloudflare plugin is unavailable; use --install-dependencies"

  install -d -o root -g root -m 0700 "$CONFIG_DIR"
  [[ -d $CONFIG_DIR && ! -L $CONFIG_DIR ]] ||
    die "Cloudflare configuration directory must not be a symlink"

  if [[ -n $credentials_source ]]; then
    read_token_file "$credentials_source"
    write_credentials "$CLOUDFLARE_TOKEN"
    unset CLOUDFLARE_TOKEN
  elif [[ ! -e $CREDENTIALS_FILE ]]; then
    [[ -t 0 ]] || die "Interactive terminal required to enter the API token"
    read -r -s -p "Enter the restricted Cloudflare API token: " CLOUDFLARE_TOKEN
    printf '\n' >&2
    write_credentials "$CLOUDFLARE_TOKEN"
    unset CLOUDFLARE_TOKEN
  else
    read_token_file "$CREDENTIALS_FILE"
    unset CLOUDFLARE_TOKEN
  fi

  credentials_owner=$(stat -c '%u' "$CREDENTIALS_FILE")
  credentials_mode=$(stat -c '%a' "$CREDENTIALS_FILE")
  [[ $credentials_owner == 0 && $credentials_mode == 600 ]] ||
    die "$CREDENTIALS_FILE must be owned by root with mode 0600"

  certbot_args=(
    certonly
    --dns-cloudflare
    --dns-cloudflare-credentials "$CREDENTIALS_FILE"
    --dns-cloudflare-propagation-seconds "$propagation_seconds"
    --non-interactive
    --agree-tos
    --email "$email"
  )
  for domain in "${domains[@]}"; do
    certbot_args+=(-d "$domain")
  done
  if [[ $staging == true ]]; then
    certbot_args+=(--staging)
  fi

  printf 'Requesting certificate for: %s\n' "${domains[*]}"
  "$CERTBOT_BIN" "${certbot_args[@]}"

  cat <<EOF

Certificate request completed.
Credentials:
  $CREDENTIALS_FILE (root:root, 0600)

Validate automatic renewal:
  sudo $CERTBOT_BIN renew --dry-run
EOF
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
