#!/usr/bin/env bash
# Local demo: replace a forked module with the central module without destroying anything.
# No cloud account is needed. It uses the built-in terraform_data resource.
# Works in a temporary folder. Needs Terraform 1.7 or later (tested on v1.17.1).
#
# What it shows (docs/04, 4.2 and 4.6; docs/02, 2.7):
#   1. A team uses a forked copy of a module. State holds module.app.terraform_data.config.
#   2. The team points to the central module, which names the resource differently.
#      Without a moved block the plan wants to DESTROY and CREATE. We do not apply it.
#   3. The central module carries a moved block. The plan only says "has moved".
#   4. The team renames its module label. A moved block in the root module keeps the state.
#   5. Verification gate: terraform plan -detailed-exitcode returns 0.
#
# Syntax: Terraform Docs, "Refactor modules"
#   https://developer.hashicorp.com/terraform/language/modules/develop/refactoring
set -euo pipefail

W="$(mktemp -d)"
cd "$W"
say() { printf '\n=== %s\n' "$*"; }
plan_lines() { terraform plan -no-color "$@" 2>&1 | grep -E 'has moved|^Plan:|No changes|must be (replaced|destroyed)|will be destroyed' || true; }
gate() { terraform plan -no-color -detailed-exitcode >/dev/null 2>&1; echo "plan -detailed-exitcode: exit code $?"; }

mkdir forked-module central-module

cat > forked-module/main.tf <<'HCL'
variable "name" { type = string }

resource "terraform_data" "config" {
  input = var.name
}
HCL

cat > central-module/main.tf <<'HCL'
variable "name" { type = string }

# The central module names this resource "settings".
resource "terraform_data" "settings" {
  input = var.name
}
HCL

cat > main.tf <<'HCL'
module "app" {
  source = "./forked-module"
  name   = "web"
}
HCL

say "STEP 1  The team uses the forked module"
terraform init -no-color >/dev/null
terraform apply -auto-approve -no-color 2>&1 | grep -E '^Apply complete'
echo "state: $(terraform state list | tr '\n' ' ')"

say "STEP 2  Point to the central module WITHOUT a moved block (not applied)"
sed -i.bak 's#./forked-module#./central-module#' main.tf && rm main.tf.bak
terraform init -no-color >/dev/null
plan_lines

say "STEP 3  The central module carries a moved block"
cat > central-module/moved.tf <<'HCL'
# Keep this block. A team that upgrades later still needs it.
moved {
  from = terraform_data.config
  to   = terraform_data.settings
}
HCL
plan_lines
terraform apply -auto-approve -no-color 2>&1 | grep -E '^Apply complete'
echo "state: $(terraform state list | tr '\n' ' ')"
gate

say "STEP 4  The team renames its module label (app to platform) with a moved block in the root"
sed -i.bak 's#module "app"#module "platform"#' main.tf && rm main.tf.bak
cat >> main.tf <<'HCL'

moved {
  from = module.app
  to   = module.platform
}
HCL
terraform init -no-color >/dev/null
plan_lines
terraform apply -auto-approve -no-color 2>&1 | grep -E '^Apply complete'
echo "state: $(terraform state list | tr '\n' ' ')"

say "STEP 5  Verification gate (docs/04, 4.3): exit code must be 0"
gate
echo "resources in state: $(terraform state list | wc -l | tr -d ' ')"

say "Done. Work folder (safe to delete): $W"
