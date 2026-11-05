# 05. Failure Scenario

**Cloud: AWS. IaC: Terraform.** Weight: 10%.

## What the task asks

Fix an apply that failed halfway, with a stuck state lock, plus a provider upgrade that wants to replace resources. Use AWS and Terraform documentation as evidence.

## 5.1 The scenario

On `prod-workload`, an apply fails halfway. The pipeline stops. A lock object stays behind. A second run waits, or fails on the lock. When the team plans again, a provider upgrade that was merged earlier now wants to replace resources.

We solve the three problems in this order: lock, half-done state, provider upgrade.

## 5.2 Stuck lock: runbook

**Facts we use**

- Terraform locks state for every operation that can write it. If locking fails, Terraform does not continue (Terraform Docs, *State: Locking*, https://developer.hashicorp.com/terraform/language/state/locking).
- With S3 native locking, the lock is an object `<key>.tflock` next to the state. A second run fails with `Error acquiring the state lock` and shows who holds the lock (AWS Prescriptive Guidance, *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html).
- `terraform plan` and `terraform apply` accept `-lock-timeout=DURATION`. They retry the lock for that time before they fail. It does nothing with `-lock=false` (Terraform Docs, *terraform plan command reference*, https://developer.hashicorp.com/terraform/cli/commands/plan and *terraform apply command reference*, https://developer.hashicorp.com/terraform/cli/commands/apply).
- `terraform force-unlock [options] LOCK_ID` removes the lock. It does not change infrastructure. `-force` skips the question. The page warns to be very careful. Unlock only your own lock, and only when automatic unlock failed. Unlocking someone else's lock can damage state (Terraform Docs, *terraform force-unlock command reference*, https://developer.hashicorp.com/terraform/cli/commands/force-unlock; *State: Locking*).

**Steps**

1. Read the error of the failing run. Find who holds the lock (a pipeline run or a person).
2. Check the holder in CodePipeline. `codepipeline:GetPipelineState` and `GetPipelineExecution` exist for this (AWS Docs, *permissions reference*, https://docs.aws.amazon.com/codepipeline/latest/userguide/permissions-reference.html).
3. If the holder is still running, wait. Pipelines use `-lock-timeout`, so a short overlap fixes itself.
4. If the holder is dead (the run failed or stopped; `codepipeline:StopPipelineExecution` is available), make sure no other run is active on that state key.
5. Only then run `terraform force-unlock LOCK_ID` through the break-glass role, with a second person watching.
6. Write down what you did. If anyone but the pipeline role deletes a `.tflock` object, the designed alert fires (see `docs/01`, section 1.7). So a real force-unlock will alert. Close the alert with the incident reference.

Where the lock ID comes from: the *State: Locking* page says `force-unlock` requires a unique lock ID, and that "Terraform will output this lock ID if unlocking fails". The AWS guide (AWS Prescriptive Guidance, *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html) says the lock error shows who holds the lock. Whether the lock ID is printed in the S3 lock-contention error itself is **unverified**. Copy the ID from the output of the failed run.

## 5.3 Half-done apply: recovery

The apply page does not say what is saved to state when an apply fails halfway, so the runbook does not assume it. We ran one local test (no AWS, `terraform_data` with a `local-exec` step that exits 1, Terraform 1.17.1). The first resource was saved. The failed resource was also saved, marked **tainted**. The next `terraform plan` printed "is tainted, so must be replaced" (`Plan: 1 to add, 0 to change, 1 to destroy`). This is one kind of failure (a failed provisioner). A create that fails at the AWS API may behave differently, and we did not test that. How an old saved plan behaves is still not covered. So this runbook does not assume either.

1. Stop more runs. Stop the pipeline run and fix the lock (5.2).
2. Save the current state version. S3 Versioning lets you restore an older version (*Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html).
3. Make state match reality. `terraform plan -refresh-only` plans only to update state and root outputs to match changes made outside Terraform (*terraform plan command reference*).
4. Run a normal plan and read it. Objects that were created before the failure but are not in state show up as creations. Bring them into state with an `import` block (Terraform Docs, *Import resources overview*, https://developer.hashicorp.com/terraform/language/import).
5. Send the new plan through the approval stage. Then apply.
6. If state is badly wrong, restore the previous state version and repeat from step 3.

A saved plan file holds the configuration, planned values, options and input variables. The plan page says sensitive data "will be saved in cleartext in the plan file" and to "treat any saved plan files as potentially-sensitive artifacts" (*terraform plan command reference*). Treat it as secret. Protect the pipeline artifact store.

## 5.4 Provider upgrade that wants to replace things

**Why it can show up late.** The dependency lock file saves the chosen provider version. `terraform init` reuses it. `terraform init -upgrade` picks the newest version that fits the constraints. Commit the lock file, so a provider change shows up in code review (Terraform Docs, *Dependency Lock File (.terraform.lock.hcl)*, https://developer.hashicorp.com/terraform/language/files/dependency-lock).

**Steps**

1. Treat any change to the lock file as a reviewed change. The upgrade is its own pull request.
2. Read the plan. You can review a saved plan with `terraform show` on the plan file before you apply (Terraform Docs, *terraform apply command reference*).
3. If the plan wants to destroy or replace resources that hold data, **reject it at the approval stage**. A rejection fails the action, and the pipeline does not go on (AWS Docs, *Add a manual approval action to a stage*, https://docs.aws.amazon.com/codepipeline/latest/userguide/approvals.html).
4. Go back to the old provider version. Restore the lock file and tighten the version constraint. The `~>` operator allows only patch releases inside the stated minor version (*Provider Requirements*, https://developer.hashicorp.com/terraform/language/providers/requirements).
5. Read the provider release notes. Make the needed config changes on a non-production stack first. Then try again.
6. Automatic detection (design, field confirmed and run locally): save the plan with `-out`, then run `terraform show -json PLANFILE`. In the plan JSON page (Terraform Docs, *JSON Output Format*, https://developer.hashicorp.com/terraform/internals/json-format) each entry in `resource_changes` has `change.actions`. The page lists the replace actions as `["delete", "create"]` and `["create", "delete"]`, and says they are written this way "to allow callers to e.g. just scan the list for \"delete\" to recognize all three situations where the object will be deleted". So the check is: fail the Plan stage if `delete` is in `actions` for a protected resource type. We ran it on a local test (`terraform_data`, no AWS): a replaced resource printed `['delete', 'create']` and an unchanged one printed `['no-op']`. We did not run it inside a pipeline. The *State* page says the state format "is subject to change in new Terraform versions", so do not parse state files directly (https://developer.hashicorp.com/terraform/language/state).

The `lifecycle` settings that protect resources (for example, stop destroy) are on the resource behavior page. We did not read it, so we do not rely on them.

## 5.5 Prevent and detect

| Control | Prevents or detects | Evidence |
|---|---|---|
| Review of the lock file | Prevents a silent provider upgrade | *Dependency Lock File (.terraform.lock.hcl)* |
| Approval stage | Prevents a replacement nobody reviewed | *Add a manual approval action to a stage* |
| `-lock-timeout` in pipeline commands | Fewer lock failures from short overlaps | *terraform plan command reference*, *terraform apply command reference* |
| One pipeline per layer and state key | A stuck lock hurts only one stack | `docs/01`, section 1.2 |
| Alert when a non-pipeline principal deletes a `.tflock` | Detects an unsafe manual unlock | AWS *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html |
| S3 Versioning | Lets you restore an older state | AWS *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html |

## Known limits

- The pages we read do not say how state behaves after a half-done apply. The steps do not depend on it.
- The *State: Locking* page says the lock ID is output when unlocking fails. We did not confirm that it is also printed in the S3 lock-contention error.
- Replacement detection from plan JSON is a design. We confirmed the field and ran it locally on a saved plan (5.4, step 6), but it is not a pipeline check that has been run.

## Sources

See [SOURCES.md](../SOURCES.md).
