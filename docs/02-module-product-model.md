# 02. Module Product Model

**Cloud: AWS. IaC: Terraform.** Weight: 20%.

## What the task asks

Define how modules look, how they combine, how they get version numbers, how they are tested and documented, who owns them, how old versions are retired, and how upgrades are automated. Use AWS and Terraform documentation as evidence.

## The idea in one paragraph

Treat each module like a small product. It has one owner, a clear interface and a test suite. Teams use a module by pinning a version. They never copy it. This fixes the fork problem: one source, many users, and upgrades that are chosen on purpose.

## 2.1 How a module looks

Every module uses the standard Terraform layout:
- `main.tf` is the main file.
- `variables.tf` and `outputs.tf` are the inputs and outputs.
- `README.md` explains it.
- Nested modules go under `modules/`. Usage examples go under `examples/`.
- Every variable and output has a short `description`. Tools use it to make docs.

Source: Terraform Docs, *Standard Module Structure*, https://developer.hashicorp.com/terraform/language/modules/develop/structure

Rules in this design:
- Every input has a `type` and a `description`.
- An input that must follow a platform standard has a `validation` block. The condition must be `true`, or Terraform shows our `error_message` (Terraform Docs, *Validate your infrastructure in Terraform's configuration language*, https://developer.hashicorp.com/terraform/language/validate).
- Outputs are the only way for a caller to read a module's results.
- Provider needs go in `required_providers` with a `source` and a `version`. Terraform Docs suggest `>=` for reusable modules and `~>` for root modules (Terraform Docs, *Provider Requirements*, https://developer.hashicorp.com/terraform/language/providers/requirements).

Example in this repo: [`modules/secure-state-bucket`](../modules/secure-state-bucket/). It makes an S3 bucket for state that has versioning, KMS encryption and no public access. The `kms_key_arn` input has a `validation` block. The provider constraint is `>= 5.0`. The resources follow the AWS provider docs for `aws_s3_bucket`, `aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration` and `aws_s3_bucket_public_access_block`.

### Second module: `layer-roles`

[`modules/layer-roles`](../modules/layer-roles/) creates the plan role and the apply role for one layer in one virtual account (`docs/01`, 1.3). It is the code behind the state/identity matrix:

- Names follow `<virtual-account>-<layer>-plan` and `-apply`.
- Each trust policy uses `codebuild.amazonaws.com` with `Condition: StringEquals: aws:SourceArn` set to one CodeBuild project. The form is from AWS Docs, *Allow CodeBuild to interact with other AWS services*, https://docs.aws.amazon.com/codebuild/latest/userguide/setting-up-service-role.html.
- State permissions follow Terraform Docs, *Backend Type: s3*, section "Permissions Required": `s3:ListBucket` on the bucket; `s3:GetObject` and `s3:PutObject` on the state key ("`s3:DeleteObject` is not required on the state file"); with `use_lockfile`, `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` on the lock file `<key>.tflock`; and `kms:Encrypt`, `kms:Decrypt`, `kms:GenerateDataKey` on the KMS key. Object permissions are limited to `<layer>/*`, so a layer cannot reach another layer's state.
- The plan role writes only `*.tflock`. The apply role has `permissions_boundary`, and cannot delete the state object.
- Resource arguments: AWS provider docs for `aws_iam_role` (`assume_role_policy`, `name`, `permissions_boundary`, `tags`) and `aws_iam_role_policy` (`name`, `role`, `policy`).

Nine tests, using `mock_provider`: role names, trust bound to one project, boundary only on apply, plan writes only the lock object, apply cannot delete the state object, state access limited to the layer prefix, and three `expect_failures` for bad input. Result on Terraform v1.17.1: 9 passed, 0 failed. When we broke the plan policy on purpose, and again when we let the apply role delete the state object, the matching test failed each time, so the tests do catch those mistakes.

## 2.2 How modules combine

- Keep modules small, with one job each. The caller (the stack) joins them. Modules should not call each other in a deep chain. Terraform Docs say nested modules should be "composable by the caller" (*Standard Module Structure*).
- Example: `secure-state-bucket` makes the bucket, `layer-roles` makes the roles. The stack passes the bucket ARN from one to the other, and the modules do not call each other.
- Stacks in `stacks/` are the top level. One stack has one state key. It calls modules by a pinned source.
- Ways to point to a module (Terraform Docs, *module block reference*, https://developer.hashicorp.com/terraform/language/block/module):
  - Local paths (`./` or `../`) point to a folder on disk.
  - The module registry supports a `version` constraint.
  - Git sources are pinned with `?ref=<tag>`.
  - S3 sources (`s3::` prefix) must be archives, for example `.zip` or `.tar.gz`.
- The `version` argument "only applies when installing modules from a registry". For other sources it does not apply. So this design pins shared modules by Git tag.

## 2.3 Version numbers

This is a rule of our design. The Terraform pages we read about module sources and tests do not define version-number rules for our own modules.

| Change | Part that goes up | Example |
|---|---|---|
| Interface change that can replace a resource, or removes an input or output | MAJOR | `v2.0.0` |
| New optional input or new output that does not break anyone | MINOR | `v1.3.0` |
| Bug fix, same interface | PATCH | `v1.3.1` |

A release is a Git tag (`vMAJOR.MINOR.PATCH`). Users pin it with `source = "git::<url>?ref=v1.3.1"`. We only release after the tests pass.

## 2.4 Tests

We use the Terraform built-in test tool.
- `terraform test` "searches the current directory and the specified testing directory for Terraform testing files". "By default, the directory containing test files is named tests." Terraform discovers test files by the extension `.tftest.hcl` or `.tftest.json`.
- A `run` block uses `command = plan` or `apply`.
- An `assert` block needs a `condition` and an `error_message`.
- `mock_provider` replaces the real provider, so no real resources are needed.
- `expect_failures` checks that bad input is rejected.

Source: Terraform Docs, *terraform test command reference*, https://developer.hashicorp.com/terraform/cli/commands/test; *Tests - Configuration Language*, https://developer.hashicorp.com/terraform/language/tests; *Tests - Provider Mocking*, https://developer.hashicorp.com/terraform/language/tests/mocking. The Tests page says "Terraform v1.7.0 introduced the ability to mock data returned by the providers during a terraform test execution". The Terraform v1.7 changelog lists `mock_provider` among the new blocks (https://github.com/hashicorp/terraform/blob/v1.7/CHANGELOG.md).

Sample test: [`modules/secure-state-bucket/tests/basic.tftest.hcl`](../modules/secure-state-bucket/tests/basic.tftest.hcl). It has four runs:

| Run | What it proves |
|---|---|
| `versioning_is_enabled` | Versioning is `Enabled` |
| `encryption_uses_kms` | Encryption is `aws:kms` |
| `public_access_is_blocked` | All four public-access-block settings are `true` |
| `rejects_invalid_kms_arn` | The validation rejects a value that is not a KMS ARN |

**Result (Terraform v1.17.1, run on 2026-11-04):** `terraform validate` passed. `terraform test` showed `4 passed, 0 failed`.

The Tests page says "By default, tests within Terraform create real infrastructure", and that "At the conclusion of a test file, Terraform attempts to destroy every resource it created". With `command = plan` no new infrastructure is created. We use `command = plan` and `mock_provider` for all sample tests. Tests that create real resources are kept for checks before a release, in a separate environment.

## 2.5 Documentation

- A `README.md` at the module root, and for each nested module meant for outside use (*Standard Module Structure*).
- Each README has: purpose, inputs, outputs, owner, current version and upgrade notes.
- Input and output tables are made from the descriptions. We do not write them by hand twice.

## 2.6 Ownership

- Each module has one owning team. It is written in the README and in the `Owner` tag that stacks set (example: `stacks/nonprod/baseline`).
- The central platform group owns the standard modules for the `baseline` and `platform` layers. Product teams own modules that are only for their `workload` layer.
- How to force the owner to review changes (for example, required reviewers) is a Git host feature. The AWS and Terraform docs we used do not cover it.

## 2.7 Keeping old users working, and retiring old versions

- **A rename or move does not break anyone, if you record it.** A `moved` block with `from` and `to` makes Terraform rename the object in state. It does not destroy and recreate it. Keep old `moved` blocks so older users can still upgrade. Removing one is a breaking change (Terraform Docs, *Refactor modules*, https://developer.hashicorp.com/terraform/language/modules/develop/refactoring).
- **Splitting a module:** keep the old module as a thin wrapper that calls the new modules and has the `moved` blocks (*Refactor modules*).
- **Replacing a fork with the central module** is shown by [`examples/fork-migration-demo`](../examples/fork-migration-demo/). The central module renames a resource and carries a `moved` block for it. Without the block, the plan for a team that switches over says `Plan: 1 to add, 0 to change, 1 to destroy.` With the block it says `has moved` and `Plan: 0 to add, 0 to change, 0 to destroy.` This is why old `moved` blocks must be kept: a team that upgrades months later still depends on them.
- **Retire policy (our design):** announce it in the README and in a MINOR release. Keep the old interface for at least one MAJOR cycle. Remove it only in the next MAJOR release.
- The *variable block reference* lists a `deprecated = "<STRING>"` argument, and the *module block reference* lists `ignore_nested_deprecations` (Terraform Docs, https://developer.hashicorp.com/terraform/language/block/variable and https://developer.hashicorp.com/terraform/language/block/module). We did not check which Terraform version added them, or how they behave in a plan, so we do not depend on them.

## 2.8 Upgrade automation

- **Providers:** `.terraform.lock.hcl` saves the chosen provider `version`, `constraints` and `hashes`. `terraform init` reuses the saved version. `terraform init -upgrade` picks the newest version that fits the constraints. The file covers providers only, not remote modules. Commit it so people can review changes (Terraform Docs, *Dependency Lock File (.terraform.lock.hcl)*, https://developer.hashicorp.com/terraform/language/files/dependency-lock).
- **Modules:** changing the pinned `?ref=` tag in a stack starts the normal pipeline (plan, approval, apply). So every upgrade is a reviewed change.
- A bot that opens upgrade pull requests could be added. We did not pick one, because the AWS and Terraform docs we used do not cover any.

## Known limits

- **One account only:** tests use a mock provider. No module has been applied to real infrastructure yet.
- `layer-roles`: it is **unverified** whether `terraform plan` needs `s3:PutObject` on the state object itself. The docs list Get and Put on the state key without saying which command needs which. The module cannot check that `plan_policy_json` is read-only.
- `examples/` is not included for the sample module. The standard says examples should use an outside source address, and none is published yet.
- Versions: the modules need Terraform 1.7 or later (`mock_provider`). The stack needs 1.11 or later (`use_lockfile`). Tests ran on Terraform v1.17.1, first with a downloaded binary and again with the v1.17.1 installed on the author's machine.
- The version number rules and the ownership rules are choices in this design. They are not product behavior.

## Sources

See [SOURCES.md](../SOURCES.md).
