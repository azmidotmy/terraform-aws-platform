# 04. Migration

**Cloud: AWS. IaC: Terraform.** Weight: 20%.

## What the task asks

Plan how to move from local state and forked modules to the new platform. Cover: finding what exists, importing and moving, checking, going back, and adoption waves. Use AWS and Terraform documentation as evidence.

## The idea in one paragraph

Move in small waves. Start with the platform's own stacks and low-risk non-production workloads. For each stack: find what exists, bring it under the central state **without changing real infrastructure**, prove that a plan shows no changes, and keep a way back. Nothing moves without a passing check.

## 4.1 Discovery

We need two lists.

**Resources that exist in AWS.** AWS Resource Explorer searches resources by name, tag and ID.
- Since 6 October 2025 it is on by default.
- For search across Regions, you choose an aggregator Region.
- Search across accounts works through AWS Organizations with trusted access.
- Search has no extra cost.
- The AWS Malaysia Region (`ap-southeast-5`) is on its supported Region list.

Source: AWS Docs, *What is AWS Resource Explorer?*, https://docs.aws.amazon.com/resource-explorer/latest/userguide/welcome.html

**Code and state that exist in the repos.** For each of the hundreds of repos, write down:
- the repo and its owner
- the Terraform version
- where its state is (a local file or a backend)
- which modules it calls, and whether they are forks
- which provider versions are locked

We build this list by scanning the repos. The AWS and Terraform docs we used do not describe a tool for this, so we did not pick one.

**Result:** a register with one row per stack and a risk rating (production impact, shared resources, state location).

## 4.2 Import and move

| Situation | Tool | Notes (from the docs) |
|---|---|---|
| The resource exists but is in no state | `import` block with `to` (resource address) and `id`, or `identity` (v1.12 or later) | Run `terraform plan` to check the import plan, then apply to import. A `resource` block must exist for each target. `id` and `identity` cannot be used in the same block. `for_each` is allowed in an import block. The page recommends keeping import blocks "as an historical artifact". Generating configuration (`terraform plan -generate-config-out=...`) is "an experimental feature" (Terraform Docs, *Import resources overview*, https://developer.hashicorp.com/terraform/language/import; *Import existing resources into Terraform state*, https://developer.hashicorp.com/terraform/language/import/single-resource; *import block reference*, https://developer.hashicorp.com/terraform/language/block/import; *Import - Generating Configuration*, https://developer.hashicorp.com/terraform/language/import/generating-configuration; the `identity` version is from the Terraform v1.12 changelog, https://github.com/hashicorp/terraform/blob/v1.12/CHANGELOG.md) |
| A resource was renamed or moved into a module | `moved` block with `from` and `to` | State is renamed before planning, so the object is not destroyed and recreated (Terraform Docs, *Refactor modules*, https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) |
| A fork is replaced by the central module | A thin wrapper module that calls the new modules, with `moved` blocks (runnable demo in 4.6) | Same page. Keep old `moved` blocks. Removing one usually breaks users |
| A one-off state change by command | `terraform state mv SOURCE DESTINATION` | `-dry-run` lists what would move, without moving it. Tell your team first. If state changes in between, a plan can destroy and recreate the object (Terraform Docs, *terraform state mv command reference*, https://developer.hashicorp.com/terraform/cli/commands/state/mv) |

Order of choice: use `import` and `moved` blocks first. They are written in code, reviewed in a pull request, and shown in a plan. Use `terraform state mv` only when a block cannot do the job.

### Moving a local state file to the shared S3 backend

What the docs say (checked against the page text on 2026-11-04):

- You can change backend configuration at any time, and the type of backend too (the page's example is from `consul` to `s3`). Terraform detects the change, and "gives you the option to migrate your state to the new backend" (Terraform Docs, *Backend block configuration overview*, https://developer.hashicorp.com/terraform/language/backend).
- The page warns: "Before migrating to a new backend, we strongly recommend manually backing up your state by copying your terraform.tfstate file to another location." (same page).
- `terraform init` on an already-initialized directory: "Either -reconfigure or -migrate-state must be supplied to update the backend configuration." `-migrate-state` "will attempt to copy existing state to the new backend" and may ask for confirmation. `-force-copy` suppresses the prompts, answers "yes", and turns on `-migrate-state`. `-reconfigure` "disregards any existing configuration, preventing migration of any existing state" (Terraform Docs, *terraform init command reference*, https://developer.hashicorp.com/terraform/cli/commands/init).
- `-backend-config=...` supplies a partial backend configuration when settings are dynamic or sensitive (same page; *Backend block configuration overview*).
- The local backend's state file defaults to `terraform.tfstate` in the root module, with a `-backup` option for backup files (Terraform Docs, *Backend Type: local*, https://developer.hashicorp.com/terraform/language/backend/local).

Steps for one stack (the order is ours; each command and flag is from the pages above):

1. Copy `terraform.tfstate` to a safe place. Keep it until step 5 passes.
2. Add the `backend "s3"` block from `docs/01`, 1.2 (and `-backend-config` for values that must not be in Git).
3. Run `terraform init -migrate-state`. Answer the prompt by hand. Do not use `-force-copy` for the first stacks.
4. Check that the object now exists at `<layer>/<stack>/terraform.tfstate` in the state bucket of the right virtual account.
5. Run `terraform plan -detailed-exitcode`. Exit code `0` is the pass mark (4.3).
6. Only then archive the local file and remove it from the repo.

Do **not** use `-reconfigure` for this job. It skips the copy, so the new backend would start empty and a plan would try to create everything again.

**Unverified for S3:** how `-migrate-state` treats the lock object when `use_lockfile = true`, and whether the old local file stays after a copy into S3. In the local-to-local demo (4.6) the old file stayed. The pages we read do not say. This is why step 1 keeps a copy.

## 4.3 Checking

A migration step is done only when **all** of these are true:

1. `terraform plan -detailed-exitcode` returns exit code `0`, which means no changes. (The option gives `0` for no changes, `1` for an error and `2` for changes. Source: Terraform Docs, *terraform plan command reference*, https://developer.hashicorp.com/terraform/cli/commands/plan.)
2. The plan shows no destroy or replace for the moved stack.
3. The number of objects in state equals the number in the register.
4. A second reviewer approves in the pipeline approval stage.

Use `terraform plan -refresh-only` when you only need to update state to match changes made outside Terraform (*terraform plan command reference*).

## 4.4 Going back (rollback)

| Where it fails | How to go back |
|---|---|
| Before the first apply of the migration | Close the pull request. Nothing changed |
| Import or move was applied and state is wrong | Restore the old state version from S3 Versioning (AWS Prescriptive Guidance, *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html) |
| A resource is tied to the wrong address | Reverse the move with a new `moved` block, or `terraform state mv` after a `-dry-run` |
| Real infrastructure changed in a way we did not expect | Stop the pipeline. Follow the failure runbook in `docs/05-failure-scenario.md` |

Copy the old state before the cutover. The `state mv` backup options work for local state files only (says the page). With a remote backend we depend on bucket versioning.

## 4.5 Adoption waves

| Wave | What | To start | To finish |
|---|---|---|---|
| 0 | The platform's own stacks (`platform` virtual account) | Pipeline and state backend are deployed | All platform stacks run through the pipeline |
| 1 | A few low-risk non-production stacks | Wave 0 is stable | Checks pass. No direct applies outside the pipeline |
| 2 | The other non-production stacks | Lessons from wave 1 are used | Checks pass for each stack |
| 3 | Production stacks, a few at a time | Wave 2 is done. Rollback is tested | Checks pass and two approvals are given |
| 4 | Leftovers and forks | Wrapper modules are ready | Forks are retired |

A team joins a wave when the register shows its stacks are listed and an owner is named.

## 4.6 Runnable demo (local, no cloud)

[`examples/migration-demo/run-demo.sh`](../examples/migration-demo/run-demo.sh) runs the four tools from 4.2 on a built-in `terraform_data` resource. Result on Terraform v1.17.1, 2026-11-04. The same script also ran with the Terraform v1.5.7 installed on the author's machine, with the same results:

| Step | What was done | Real output |
|---|---|---|
| 1 | Apply with state in `state-old/` | `Apply complete! Resources: 1 added, 0 changed, 0 destroyed.` |
| 2 | Change the backend path, run `terraform init -migrate-state -force-copy` | `state-new/terraform.tfstate` exists. The old file is **still there**. `terraform plan -detailed-exitcode` exit code `0` |
| 3 | Rename the resource, add a `moved` block | `# terraform_data.web has moved to terraform_data.frontend`, then `Plan: 0 to add, 0 to change, 0 to destroy.` Exit code `0` |
| 4 | `terraform state rm`, then add an `import` block | `Plan: 1 to import, 0 to add, 1 to change, 0 to destroy.` then `Apply complete! Resources: 1 imported, 0 added, 1 changed, 0 destroyed.` |
| 5 | Verification gate | Exit code `0`. 1 resource in state |

What this teaches:

- **`moved` is safe.** The plan shows the move and no destroy.
- **A plan right after an import is not clean.** In step 4 the plan shows `1 to change`, because the import brings in the object but the argument `input` was not in the imported state. So the rule in 4.3 is: apply the import, then run the plan again, and require exit code `0` on the second plan. Always read the "to change" lines after an import before approval.
- **`-migrate-state` leaves the old local file in place** (local to local backend). Keep it until step 5 passes, then archive it.

### Replacing a fork with the central module

*Like changing the name of your street. Without a letter to the post office, the postman thinks the old house is gone and a new house has appeared. With the letter (the `moved` block), the postman knows it is the same house.*

[`examples/fork-migration-demo/run-demo.sh`](../examples/fork-migration-demo/run-demo.sh) shows the case in the scenario where modules were forked. Result on Terraform v1.17.1, 2026-11-04:

| Step | What was done | Real output |
|---|---|---|
| 1 | Apply with the forked module | `state: module.app.terraform_data.config` |
| 2 | Point to the central module, which names the resource `settings`, **without** a `moved` block (not applied) | `# module.app.terraform_data.config will be destroyed` and `Plan: 1 to add, 0 to change, 1 to destroy.` |
| 3 | Add a `moved` block inside the central module, apply | `# module.app.terraform_data.config has moved to module.app.terraform_data.settings`, `Plan: 0 to add, 0 to change, 0 to destroy.`, exit code `0` |
| 4 | Rename the module label (`app` to `platform`) with a `moved` block in the root module | `# module.app.terraform_data.settings has moved to module.platform.terraform_data.settings`, `Plan: 0 to add, 0 to change, 0 to destroy.` |
| 5 | Verification gate | `plan -detailed-exitcode`: exit code `0`. 1 resource in state |

What this teaches:

- **The danger is real and the plan shows it.** Switching a fork for the central module can mean destroy and create. Step 2 is why rule 2 of 4.3 ("no destroy or replace") is a gate.
- **The fix lives in the central module.** The `moved` block ships with the module, so every team that switches gets the same safe plan. This is the "shim" idea from 4.2 in a runnable form.
- **Keep old `moved` blocks.** The Refactor modules page says: "Note that removing a moved block is a breaking change." A team that switches late still needs it.

Limits of the demos: they use the `local` backend, not S3, and `terraform_data`, not AWS resources. The behavior of `-migrate-state` with the S3 backend and `use_lockfile` (4.2) is still **unverified**, and import of real AWS resources depends on the provider.

## Known limits

- Hundreds of repos are described, not migrated. No migration has been run in this submission.
- The *Import - Generating Configuration* page calls configuration generation experimental and says later minor versions may change it. Do not rely on generated configuration. We did not read the command to move local state to a backend beyond `terraform init` and the backend page.
- The repo and state scan has no named tool.
- The local-to-S3 steps were not run. Only a local-to-local demo was run (4.6). Behavior with S3 and the lock object is **unverified**.

## Sources

See [SOURCES.md](../SOURCES.md).
