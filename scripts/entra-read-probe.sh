#!/bin/bash
# Records, once per run, whether the signed-in identity can read
# Microsoft Entra ID, and which kind of read works.
# Inputs: an Azure command-line interface (CLI) login, and ARM_CLIENT_ID
# (the application's client id). On the GitHub runner both come from the
# OpenID Connect (OIDC) sign-in.
# Output: one line per probe: ALLOWED, DENIED, NOT_FOUND, or ERROR, plus the
# Microsoft Graph error code when there is one. Never prints ids or names.
# Side effects: none. Read-only. Always exits 0, because this is a
# measurement, not a gate. verify.sh is the gate.

set -u
set -o pipefail

app_name="github-actions-azure-terraform-pipeline-poc"
errf="$(mktemp)"
trap 'rm -f "$errf"' EXIT

report() {
  local label="$1" rc="$2" code
  if [[ "$rc" -eq 0 ]]; then
    printf '%s: ALLOWED\n' "$label"
    return
  fi
  code="$(grep -o -i -E 'Authorization_RequestDenied|Insufficient privileges|Request_ResourceNotFound|Forbidden|Unauthorized' "$errf" | head -1)"
  case "$code" in
    Authorization_RequestDenied | "Insufficient privileges" | Forbidden | Unauthorized)
      printf '%s: DENIED (%s)\n' "$label" "$code" ;;
    Request_ResourceNotFound)
      printf '%s: NOT_FOUND (%s)\n' "$label" "$code" ;;
    *)
      printf '%s: ERROR (no known Graph code in the message)\n' "$label" ;;
  esac
}

echo "Entra read probe"

if [[ -z "${ARM_CLIENT_ID:-}" ]]; then
  echo "ARM_CLIENT_ID is not set, so the by-id probes cannot run."
else
  az ad app show --id "$ARM_CLIENT_ID" --query displayName -o tsv >/dev/null 2>"$errf"
  report "1 read own application by id (what Terraform refresh does)" "$?"

  az ad app federated-credential list --id "$ARM_CLIENT_ID" --query "length(@)" -o tsv >/dev/null 2>"$errf"
  report "2 list own federated credentials by id" "$?"
fi

count="$(az ad app list --display-name "$app_name" --query "length(@)" -o tsv 2>"$errf")"
rc=$?
report "3 search applications by display name (what verify.sh did before)" "$rc"
if [[ "$rc" -eq 0 ]]; then
  printf '3 search returned %s matching application(s)\n' "${count:-unknown}"
fi

exit 0
