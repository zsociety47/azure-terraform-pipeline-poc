#!/bin/bash
# Reads the live pipeline bootstrap and prints a pass/fail table.
# Inputs: an Azure command-line interface (CLI) login. The subscription id
# is taken from ARM_SUBSCRIPTION_ID when that variable is set, and from the
# current CLI account when it is not. The names below match variables.tf.
# Output: numbered PASS or FAIL lines. Exit 0 when all pass, exit 1 otherwise.
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
pass() { printf '%s  %s: PASS\n' "$1" "$2"; }
fail() { printf '%s  %s: FAIL\n' "$1" "$2"; failed=1; }

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

# The GitHub runner can sign in with OpenID Connect. It cannot
# read Microsoft Entra ID applications. Checks 7 and 8 run on
# the laptop. They are skipped, not failed, on the runner.
skip() { printf '%s  %s: SKIP\n' "$1" "$2"; }

app_object_id="$(az ad app list --display-name "$app_name" --query "[0].id" -o tsv 2>/dev/null || true)"
if [[ -z "$app_object_id" ]]; then
  skip 7 "${app_name} is AzureADMyOrg with no client secret (this login cannot read Microsoft Entra ID)"
  skip 8 "Federated credentials github-pull-request and github-main exist (this login cannot read Microsoft Entra ID)"
else
  app_facts="$(az ad app list \
    --display-name "$app_name" \
    --query "[0].{audience:signInAudience, secrets:length(passwordCredentials)}" \
    -o json 2>/dev/null || echo '{}')"
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

  cred_names="$(az ad app federated-credential list --id "$app_object_id" --query "[].name" -o json 2>/dev/null || echo '[]')"
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

exit "$failed"
