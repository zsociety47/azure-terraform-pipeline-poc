#!/bin/bash
# Reads the live pipeline bootstrap and prints a pass/fail table.
# Inputs: an Azure command-line interface (CLI) login. The subscription id
# is taken from ARM_SUBSCRIPTION_ID when that variable is set, and from the
# current CLI account when it is not. The names below match variables.tf.
# Output: numbered PASS, FAIL, or SKIP lines, then a count. Exit 0 when nothing
# failed, exit 1 otherwise. SKIP is not a failure, and it is used only when
# Microsoft Entra ID refuses the read with a permission error. A missing
# application is a FAIL, never a SKIP.
# Side effects: none. This script does not create or delete Azure resources.
# It does not print subscription ids, tenant ids, or principal ids.

set -u
set -o pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

state_group="rg-tfpipe-state-zeon01"
pipeline_group="rg-tfpipe-poc-zeon01"
storage_account="sttfpipezeon01"
pipeline_storage_account="sttfpipepoczeon01"
container_name="tfstate"
state_blob="pipeline.tfstate"
location="eastus"
app_name="github-actions-azure-terraform-pipeline-poc"

if [[ -z "${ARM_SUBSCRIPTION_ID:-}" ]]; then
  ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
  export ARM_SUBSCRIPTION_ID
fi

failed=0
passed=0
skipped=0
pass() { printf '%s  %s: PASS\n' "$1" "$2"; passed=$((passed + 1)); }
fail() { printf '%s  %s: FAIL\n' "$1" "$2"; failed=1; }
skip() { printf '%s  %s: SKIP\n' "$1" "$2"; skipped=$((skipped + 1)); }

tags_ok() {
  local json="$1"
  local lifetime="$2"
  printf '%s' "$json" | python3 -c '
import json, sys
tags = json.load(sys.stdin)
lifetime = sys.argv[1]
needed = ("lifetime", "owner", "project", "created")
ok = (
    all(tags.get(k) for k in needed)
    and tags.get("lifetime") == lifetime
    and tags.get("owner") == "zeon"
    and tags.get("project") == "azure-terraform-pipeline-poc"
)
print("yes" if ok else "no")
' "$lifetime"
}

role_present() {
  local json="$1"
  local role="$2"
  local kind="$3"
  printf '%s' "$json" | python3 -c '
import json, sys
rows = json.load(sys.stdin)
role, kind = sys.argv[1], sys.argv[2]
ok = any(r.get("role") == role and r.get("kind") == kind for r in rows)
print("yes" if ok else "no")
' "$role" "$kind"
}

group_location="$(az group show --name "$state_group" --query location -o tsv 2>/dev/null || true)"
if [[ "$group_location" == "$location" ]]; then
  pass 1 "Resource group ${state_group} is in ${location}"
else
  fail 1 "Resource group ${state_group} is in ${location}"
fi

group_location="$(az group show --name "$pipeline_group" --query location -o tsv 2>/dev/null || true)"
if [[ "$group_location" == "$location" ]]; then
  pass 2 "Resource group ${pipeline_group} is in ${location}"
else
  fail 2 "Resource group ${pipeline_group} is in ${location}"
fi

state_tags="$(az group show --name "$state_group" --query tags -o json 2>/dev/null || echo '{}')"
if [[ "$(tags_ok "$state_tags" "keep")" == "yes" ]]; then
  pass 3 "${state_group} has owner, project, created, and lifetime=keep"
else
  fail 3 "${state_group} has owner, project, created, and lifetime=keep"
fi

pipeline_tags="$(az group show --name "$pipeline_group" --query tags -o json 2>/dev/null || echo '{}')"
if [[ "$(tags_ok "$pipeline_tags" "1d")" == "yes" ]]; then
  pass 4 "${pipeline_group} has owner, project, created, and lifetime=1d"
else
  fail 4 "${pipeline_group} has owner, project, created, and lifetime=1d"
fi

storage_ok="$(az storage account show \
  --name "$storage_account" \
  --resource-group "$state_group" \
  --query "{httpsOnly:enableHttpsTrafficOnly, sharedKeys:allowSharedKeyAccess}" \
  -o json 2>/dev/null || echo '{}')"
storage_pass="$(printf '%s' "$storage_ok" | python3 -c '
import json, sys
facts = json.load(sys.stdin)
print("yes" if facts.get("httpsOnly") is True and facts.get("sharedKeys") is False else "no")
')"
if [[ "$storage_pass" == "yes" ]]; then
  pass 5 "${storage_account} has HTTPS only and shared keys off"
else
  fail 5 "${storage_account} has HTTPS only and shared keys off"
fi

blob_name="$(az storage blob list \
  --account-name "$storage_account" \
  --container-name "$container_name" \
  --auth-mode login \
  --query "[?name=='${state_blob}'].name | [0]" \
  -o tsv 2>/dev/null || true)"
if [[ "$blob_name" == "$state_blob" ]]; then
  pass 6 "Blob ${state_blob} is in ${container_name}"
else
  fail 6 "Blob ${state_blob} is in ${container_name}"
fi

# Checks 7 and 8 read Microsoft Entra ID. Reading it can fail for three
# different reasons, and they are not the same result:
#   readable      -> run the check. PASS or FAIL.
#   permission denied by Entra -> SKIP, and say so with the Graph error code.
#   not found, or any other error -> FAIL. A missing app must never go green.
# On the GitHub runner ARM_CLIENT_ID is set, so the app is read by id, the
# same read Terraform does on every plan. On the laptop it is found by name.
errf="$(mktemp)"
trap 'rm -f "$errf"' EXIT

graph_code() {
  grep -o -i -E 'Authorization_RequestDenied|Insufficient privileges|Request_ResourceNotFound|Forbidden|Unauthorized' "$errf" | head -1
}

is_denied() {
  case "$(graph_code)" in
    Authorization_RequestDenied | "Insufficient privileges" | Forbidden | Unauthorized) return 0 ;;
    *) return 1 ;;
  esac
}

app_query="{object:id, audience:signInAudience, secrets:length(passwordCredentials)}"
if [[ -n "${ARM_CLIENT_ID:-}" ]]; then
  app_facts="$(az ad app show --id "$ARM_CLIENT_ID" --query "$app_query" -o json 2>"$errf")"
  app_rc=$?
else
  app_facts="$(az ad app list --display-name "$app_name" --query "[0].${app_query}" -o json 2>"$errf")"
  app_rc=$?
fi

if [[ "$app_rc" -ne 0 ]] && is_denied; then
  skip 7 "${app_name} is AzureADMyOrg with no client secret (Entra refused this login: $(graph_code))"
  skip 8 "Federated credentials github-pull-request and github-main exist (Entra refused this login: $(graph_code))"
elif [[ "$app_rc" -ne 0 ]] || [[ -z "$app_facts" ]] || [[ "$app_facts" == "null" ]]; then
  fail 7 "${app_name} is AzureADMyOrg with no client secret (application not found or unreadable)"
  fail 8 "Federated credentials github-pull-request and github-main exist (application not found or unreadable)"
else
  app_pass="$(printf '%s' "$app_facts" | python3 -c '
import json, sys
facts = json.load(sys.stdin)
print("yes" if facts.get("audience") == "AzureADMyOrg" and facts.get("secrets") == 0 else "no")
')"
  if [[ "$app_pass" == "yes" ]]; then
    pass 7 "${app_name} is AzureADMyOrg with no client secret"
  else
    fail 7 "${app_name} is AzureADMyOrg with no client secret"
  fi

  app_object_id="$(printf '%s' "$app_facts" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("object", ""))')"
  cred_names="$(az ad app federated-credential list --id "$app_object_id" --query "[].name" -o json 2>"$errf")"
  cred_rc=$?
  if [[ "$cred_rc" -ne 0 ]] && is_denied; then
    skip 8 "Federated credentials github-pull-request and github-main exist (Entra refused this login: $(graph_code))"
  elif [[ "$cred_rc" -ne 0 ]]; then
    fail 8 "Federated credentials github-pull-request and github-main exist (read failed)"
  else
    cred_pass="$(printf '%s' "$cred_names" | python3 -c '
import json, sys
names = set(json.load(sys.stdin))
print("yes" if {"github-pull-request", "github-main"} <= names else "no")
')"
    if [[ "$cred_pass" == "yes" ]]; then
      pass 8 "Federated credentials github-pull-request and github-main exist"
    else
      fail 8 "Federated credentials github-pull-request and github-main exist"
    fi
  fi
fi

# The storage account id includes a subscription id. It is used as
# --scope and is not printed.
account_id="$(az storage account show \
  --name "$storage_account" \
  --resource-group "$state_group" \
  --query id \
  -o tsv 2>/dev/null || true)"
blob_roles="[]"
if [[ -n "$account_id" ]]; then
  blob_roles="$(az role assignment list \
    --scope "$account_id" \
    --query "[].{role:roleDefinitionName, kind:principalType}" \
    -o json 2>/dev/null || echo '[]')"
fi
if [[ "$(role_present "$blob_roles" "Storage Blob Data Contributor" "ServicePrincipal")" == "yes" ]]; then
  pass 9 "GitHub has Storage Blob Data Contributor on the state account"
else
  fail 9 "GitHub has Storage Blob Data Contributor on the state account"
fi

state_roles="$(az role assignment list \
  --resource-group "$state_group" \
  --query "[].{role:roleDefinitionName, kind:principalType}" \
  -o json 2>/dev/null || echo '[]')"
if [[ "$(role_present "$state_roles" "Reader" "ServicePrincipal")" == "yes" ]]; then
  pass 10 "GitHub is Reader on ${state_group}"
else
  fail 10 "GitHub is Reader on ${state_group}"
fi

pipeline_roles="$(az role assignment list \
  --resource-group "$pipeline_group" \
  --query "[].{role:roleDefinitionName, kind:principalType}" \
  -o json 2>/dev/null || echo '[]')"
pipeline_ok="$(printf '%s' "$pipeline_roles" | python3 -c '
import json, sys
rows = json.load(sys.stdin)
ok = len(rows) == 1 and rows[0].get("role") == "Contributor" and rows[0].get("kind") == "ServicePrincipal"
print("yes" if ok else "no")
')"
if [[ "$pipeline_ok" == "yes" ]]; then
  pass 11 "GitHub is Contributor on ${pipeline_group} only"
else
  fail 11 "GitHub is Contributor on ${pipeline_group} only"
fi

pipeline_account="$(az storage account show \
  --name "$pipeline_storage_account" \
  --resource-group "$pipeline_group" \
  --query name \
  -o tsv 2>/dev/null || true)"
if [[ "$pipeline_account" == "$pipeline_storage_account" ]]; then
  pass 12 "Pipeline storage account ${pipeline_storage_account} exists"
else
  fail 12 "Pipeline storage account ${pipeline_storage_account} exists"
fi

printf '\n%s PASS, %s SKIP, %s\n' "$passed" "$skipped" "$([[ "$failed" -eq 0 ]] && echo "no FAIL" || echo "at least one FAIL")"
exit "$failed"
