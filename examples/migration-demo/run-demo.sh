#!/usr/bin/env bash
# Local demo of the migration tools in docs/04. No cloud account needed.
# Uses the built-in terraform_data resource, so nothing is downloaded or created in AWS.
# Works in a temporary folder. Needs Terraform (tested on v1.17.1).
#
# Commands and flags used (all from the pages listed in docs/04):
#   import block ......... Terraform Docs, "import block reference"  https://developer.hashicorp.com/terraform/language/block/import
#   moved block .......... Terraform Docs, "Refactor modules"        https://developer.hashicorp.com/terraform/language/modules/develop/refactoring
#   init -migrate-state .. Terraform Docs, "terraform init"          https://developer.hashicorp.com/terraform/cli/commands/init
#   plan -detailed-exitcode  Terraform Docs, "terraform plan"        https://developer.hashicorp.com/terraform/cli/commands/plan
set -euo pipefail

W="$(mktemp -d)"
cd "$W"
say() { printf '\n=== %s\n' "$*"; }
plan_summary() { terraform plan -no-color -detailed-exitcode "$@" 2>&1 | grep -E '^(Plan:|No changes|.*has moved)' || true; }

say "STEP 1  Existing resource, state in the OLD local backend"
cat > main.tf <<'HCL'
terraform {
  backend "local" {
    path = "state-old/terraform.tfstate"
  }
}

resource "terraform_data" "web" {
  input = "web"
}
HCL
terraform init -no-color >/dev/null
terraform apply -auto-approve -no-color 2>&1 | grep -E '^Apply complete'

say "STEP 2  Move state to the NEW backend path with: terraform init -migrate-state"
sed -i.bak 's#state-old/#state-new/#' main.tf && rm main.tf.bak
terraform init -migrate-state -force-copy -no-color 2>&1 | grep -iE 'migrat|successfully' || true
test -s state-new/terraform.tfstate && echo "state-new/terraform.tfstate exists"
echo "old state file still present: $(test -e state-old/terraform.tfstate && echo yes || echo no)"
echo "verify (expect exit code 0 = no changes):"
terraform plan -no-color -detailed-exitcode >/dev/null 2>&1; echo "exit code: $?"

say "STEP 3  moved block: rename the resource, nothing is destroyed"
sed -i.bak 's/resource "terraform_data" "web"/resource "terraform_data" "frontend"/' main.tf && rm main.tf.bak
cat >> main.tf <<'HCL'

moved {
  from = terraform_data.web
  to   = terraform_data.frontend
}
HCL
terraform plan -no-color 2>&1 | grep -E 'has moved|Plan:|No changes' || true
terraform apply -auto-approve -no-color 2>&1 | grep -E '^Apply complete'
echo "verify (expect exit code 0 = no changes):"
terraform plan -no-color -detailed-exitcode >/dev/null 2>&1; echo "exit code: $?"

say "STEP 4  import block: object exists, but is not in any state"
ID="$(terraform show -json | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["values"]["root_module"]["resources"][0]["values"]["id"])')"
terraform state rm terraform_data.frontend -no-color >/dev/null
echo "state now has $(terraform state list | wc -l | tr -d ' ') resources (the object still exists)"
cat >> main.tf <<HCL

import {
  to = terraform_data.frontend
  id = "$ID"
}
HCL
echo "plan with the import block:"
terraform plan -no-color 2>&1 | grep -E '^Plan:|to import' || true
terraform apply -auto-approve -no-color 2>&1 | grep -E '^Apply complete'

say "STEP 5  verification gate (docs/04, 4.3): exit code must be 0"
terraform plan -no-color -detailed-exitcode >/dev/null 2>&1; echo "exit code: $?"
echo "resources in state: $(terraform state list | wc -l | tr -d ' ')"

say "Done. Work folder (safe to delete): $W"
