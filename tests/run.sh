#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=certbot-cloudflare.sh
source "$repo_dir/certbot-cloudflare.sh"

validate_dns_name "example.com"
validate_dns_name "app.example.co.uk"
validate_dns_name "*.example.com"
! validate_dns_name "example"
! validate_dns_name "-bad.example.com"
! validate_dns_name "bad..example.com"

validate_token "AbCd_0123-token"
! validate_token "token with spaces"
! validate_token $'token\ninjected'

help_output=$("$repo_dir/certbot-cloudflare.sh" --help)
grep -q -- '--credentials-file' <<<"$help_output"
grep -q -- '--install-dependencies' <<<"$help_output"

if grep -Eq 'pip[[:space:]]+install|read[[:space:]]+-p.*token' \
  "$repo_dir/certbot-cloudflare.sh"; then
  printf 'Unsafe dependency or visible-token prompt detected\n' >&2
  exit 1
fi

printf 'Cloudflare wrapper tests passed\n'
