# 03. Governance

**Cloud: AWS. IaC: Terraform.** Weight: 15%.

## What the task asks

Build rules as code in three layers: guardrails for the whole organization, standards for the platform, and choices for teams. Add a lifecycle for exceptions. Use AWS and Terraform documentation as evidence.

## The three layers

| Layer | Question it answers | Tool | Who changes it |
|---|---|---|---|
| 1. Organization guardrails | What can nobody do? | Service control policies (SCPs) on the root or an OU | Central platform, with review |
| 2. Platform standards | What must every stack do? | Module input checks, permissions boundaries, bucket policies, and tested policy rules (3.5) | Central platform |
| 3. Team choices | What can a team decide? | Module inputs inside the allowed values, team IAM permissions inside the boundary | Product team |

A request is allowed only if **every layer says yes**. An SCP, a permissions boundary and an identity-based policy must all allow the action (AWS Docs, *Service control policies (SCPs)*, https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html).

## 3.1 Layer 1: organization guardrails (SCP)

What SCPs do and do not do (AWS Docs, *Service control policies (SCPs)*):

- An SCP sets the **maximum** permissions for IAM users and roles in the organization. It does not give permissions. The real permissions are what the SCP **and** the identity or resource policy both allow.
- SCPs work only in an organization with all features turned on.
- SCPs apply to member accounts, including the root user of a member account. They **do not apply to users or roles in the management account**. They do not apply to service-linked roles.
- AWS says not to attach an SCP to the root without careful testing. Test in a test OU first. Do not remove the `FullAWSAccess` policy unless another policy allows actions. If you do, all actions from member accounts fail.
- The examples page uses a deny-list style, so an allow policy such as `FullAWSAccess` must also be attached. AWS says to test in a separate organization or OU before wider use (AWS Docs, *Service control policy examples*, https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_examples.html).

Example in this repo: [`policies/scp/protect-state-and-audit.json`](../policies/scp/protect-state-and-audit.json). It denies deleting a state bucket, changing its versioning, and stopping or deleting CloudTrail.

**Status: design only.** We cannot show an SCP working with one AWS account. Also, the management account is not limited by SCPs.

**Check of the action names (page text read on 2026-11-04):**

| Item in the SCP | Result | Where it is written |
|---|---|---|
| `s3:DeleteBucket` | Found: "Required to delete an S3 bucket" | AWS Docs, *Policy actions for Amazon S3*, https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-with-s3-policy-actions.html; also *DeleteBucket* API page, https://docs.aws.amazon.com/AmazonS3/latest/API/API_DeleteBucket.html ("you must have the s3:DeleteBucket permission") |
| `s3:PutBucketVersioning` | Found: "Required to set the versioning state of an S3 bucket" | *Policy actions for Amazon S3* |
| `cloudtrail:StopLogging` | Found in a policy example | AWS Docs, *Identity-based policy examples for AWS CloudTrail*, https://docs.aws.amazon.com/awscloudtrail/latest/userguide/security_iam_id-based-policy-examples.html |
| `cloudtrail:DeleteTrail` | Found. The CloudTrail service reference lists the action `DeleteTrail` on the resource type `trail` (same file lists `StopLogging`). The IAM string is the service prefix `cloudtrail` plus this name | AWS Docs, *Service reference information*, https://docs.aws.amazon.com/service-authorization/latest/reference/service-reference.html ("AWS provides service reference information in JSON format"). File read: https://servicereference.us-east-1.amazonaws.com/v1/cloudtrail/cloudtrail.json |
| `Resource` in a Deny SCP | Found: `Resource` is supported for Allow and Deny | AWS Docs, *SCP syntax*, https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_syntax.html |
| Bucket ARN pattern `arn:aws:s3:::*-tfstate-*` | Found, for the format. The S3 service reference gives the `bucket` resource type the ARN format `arn:${Partition}:s3:::${BucketName}`, and `DeleteBucket` and `PutBucketVersioning` both act on `bucket`. The wildcard `*-tfstate-*` in the bucket name part is our naming rule. It matches only buckets named that way | AWS Docs, *Service reference information*, https://docs.aws.amazon.com/service-authorization/latest/reference/service-reference.html. File read: https://servicereference.us-east-1.amazonaws.com/v1/s3/s3.json |

The Service Authorization Reference is the full list of action names, but its pages load with JavaScript and returned no content to us, so we could not use it.

## 3.2 Layer 2: platform standards

| Standard | How | Evidence | Example |
|---|---|---|---|
| Module inputs are valid | `validation` block in a `variable` | Terraform Docs, *Validate your infrastructure in Terraform's configuration language*, https://developer.hashicorp.com/terraform/language/validate | [`modules/secure-state-bucket/variables.tf`](../modules/secure-state-bucket/variables.tf) |
| A resource meets a condition before and after planning | `precondition` and `postcondition` in `lifecycle` | *Validate your infrastructure in Terraform's configuration language* | design |
| Checks on the whole infrastructure | `check` blocks with `assert` | *Validate your infrastructure in Terraform's configuration language* | design |
| Maximum permissions of an apply role | Permissions boundary | AWS Docs, *Permissions boundaries for IAM entities*, https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html | [`policies/iam/boundary-workload-apply.json`](../policies/iam/boundary-workload-apply.json) |
| State bucket only over TLS | Bucket policy that denies `s3:*` when `aws:SecureTransport` is `false` | AWS Prescriptive Guidance, *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html | [`policies/bucket/state-bucket-tls-only.json`](../policies/bucket/state-bucket-tls-only.json) |
| Only the approver approves | IAM allow on `codepipeline:PutApprovalResult` for one action, and a deny on editing the pipeline | AWS Docs, *permissions reference* (CodePipeline), https://docs.aws.amazon.com/codepipeline/latest/userguide/permissions-reference.html | [`policies/iam/approver-prod-workload.json`](../policies/iam/approver-prod-workload.json) |

How Terraform conditions behave (*Validate your infrastructure in Terraform's configuration language*). The page lists the versions: "Terraform v0.13.0 or later for input variable validation", "v1.2.0 or later for preconditions and postconditions", "v1.5.0 or later for check blocks". This matters for governance:

- A failed `validation`, `precondition` or `postcondition` gives an **error**. A failed precondition stops the planned actions for that resource. A failed postcondition stops work that depends on it, but leaves finished actions in place.
- A failed `check` gives only a **warning**. It does not stop anything. So a `check` can **detect** a problem, but it cannot **block** it.

A permissions boundary does not give permissions. A role's real permissions are what both its identity policies and its boundary allow (*Permissions boundaries for IAM entities*). The boundary example is only an example. It must be checked against the real actions the workload layer needs.

## 3.3 Layer 3: team choices

- Teams choose module inputs that the module validation accepts (for example size, tags, and retention within limits).
- Teams manage permissions for their own workload resources, inside the permissions boundary of their apply role.
- Teams cannot change the pipeline gate, the boundary or the SCPs.

## 3.4 Exception lifecycle

AWS example OUs include an **Exceptions OU** for accounts that need exceptions to the default policies of the Workloads OU. They also include a **Policy Staging OU** to test policy changes before applying them to other OUs (AWS Prescriptive Guidance, *Configuring account structure and OUs*, https://docs.aws.amazon.com/prescriptive-guidance/latest/designing-control-tower-landing-zone/account-structure.html).

The lifecycle in this design:

| Step | What happens | Evidence kept |
|---|---|---|
| 1. Request | The team states the rule, the reason, the scope and how long | Request record with owner |
| 2. Review | The central platform group and a security reviewer judge the risk | Review decision |
| 3. Approve with an end date | Every approval has an end date | Approval record with end date |
| 4. Apply | The change goes through the normal pipeline. In a real multi-account setup, the account moves to the Exceptions OU | Pipeline run and plan file |
| 5. Watch | The exception is in a register, and its use is audited | Register entry |
| 6. End or renew | At the end date the exception is removed, or renewed after a new review | Closing record |

No exception lasts forever. Moving an account to an OU is design only in this one-account submission. The register itself is code, and it is tested (below).

### The register as code

*Like a visitor pass at an office. Every pass has an expiry date, and a guard checks the passes every day. When a pass expires, it stops working.*

The register is the file [`policies/exceptions/register.json`](../policies/exceptions/register.json). Each exception has an id, the rule, the scope, the owner, the reason, who approved it, and two dates. A `terraform test` run checks it (`cd policies/exceptions && terraform init && terraform test`). The checks are `precondition` blocks on outputs, which give an error when the condition is false (Terraform Docs, *output block reference*, https://developer.hashicorp.com/terraform/language/block/output; *Validate your infrastructure in Terraform's configuration language*, https://developer.hashicorp.com/terraform/language/validate). The functions are `timecmp`, `timeadd`, `plantimestamp`, `coalesce` and `try` (Terraform Docs, *timecmp*, https://developer.hashicorp.com/terraform/language/functions/timecmp; *timeadd*, https://developer.hashicorp.com/terraform/language/functions/timeadd; *plantimestamp*, https://developer.hashicorp.com/terraform/language/functions/plantimestamp; *coalesce*, https://developer.hashicorp.com/terraform/language/functions/coalesce; *try*, https://developer.hashicorp.com/terraform/language/functions/try).

| Rule | What it checks | Why |
|---|---|---|
| E1 | All eight fields exist, and both dates are RFC 3339 timestamps | A reviewer can read every exception the same way |
| E2 | `approved_by` is not the `owner` | Nobody approves their own exception (separation of duties) |
| E3 | `expires` is after `approved_on`, and at most 90 days (2160 hours) later | Every approval has an end date, and it is short |
| E4 | No exception has expired | "No exception is permanent." The check fails after the end date |
| E5 | Every id is unique | One id, one exception |

How the time is chosen: `today` can be given as an RFC 3339 timestamp. If it is left empty, the test uses `plantimestamp()`, the time of the plan. The page says `plantimestamp` returns a UTC timestamp in RFC 3339 format that "changes during every plan operation" and can be used to validate time-sensitive resources. A scheduled run in the pipeline therefore fails by itself on the day an exception ends.

Result on Terraform v1.17.1: **9 passed, 0 failed**. One run passes with the real register. The other eight break one rule at a time and expect that rule's output to fail: expired (E4), missing field (E1), bad date format (E1), self-approval (E2), longer than 90 days (E3), ends before it starts (E3), duplicate id (E5), and text that is not JSON. We also ran `terraform plan` by hand. On 2026-11-04 it passed. With `today` set to 2027-01-01 it failed with the E4 message.

What this is not: it does not remove the exception from AWS, and it does not check that the scope matches a real resource. It only makes sure an exception cannot stay in the register past its end date without a failing run.

## 3.5 Policy checks that run as tests

The policy files in `policies/` are checked by `terraform test`, so a change that breaks a standard fails before review. The check lives in [`policies/checks`](../policies/checks/) and uses a `variable` with `validation` blocks, which give an error when a rule is broken (Terraform Docs, *Validate your infrastructure in Terraform's configuration language*, https://developer.hashicorp.com/terraform/language/validate). The functions used are `jsondecode`, `can`, `try`, `flatten` and `alltrue` (Terraform Docs, *jsondecode*, https://developer.hashicorp.com/terraform/language/functions/jsondecode; *can*, https://developer.hashicorp.com/terraform/language/functions/can; *flatten*, https://developer.hashicorp.com/terraform/language/functions/flatten; *alltrue*, https://developer.hashicorp.com/terraform/language/functions/alltrue). The test files are read with `file()` (https://developer.hashicorp.com/terraform/language/functions/file).

| Rule | What it checks | Why |
|---|---|---|
| R1 | JSON, `Version` is `2012-10-17`, at least one statement | A broken document is caught early |
| R2 | Every statement has a `Sid` | Reviewers and audit logs can name each statement |
| R3 | No statement is `Allow` with `Action` `*` | The constraint: no all-powerful role |
| R4 | An SCP has only `Deny` statements | We use the deny-list style (AWS Docs, *Service control policy examples*) |

Run it: `cd policies/checks && terraform init && terraform test`.

Result on Terraform v1.17.1: **8 passed, 0 failed**. Four runs check the four real policy files in this repo. Four runs use bad input and expect the failure (`expect_failures`): allow-all, a statement without a `Sid`, an SCP with an `Allow`, and text that is not JSON. We also broke the real files on purpose, one at a time. Changing the SCP statement to `Allow` failed with the R4 message. Giving the approver policy `Action` `*` failed with the R3 message. The files were then restored.

What this is not: a general policy engine. It checks four rules we chose. It does not check what a policy does inside AWS, and it does not read a Terraform plan.

## Known limits

- We cannot show SCPs working here (one account, and the management account is not limited by SCPs).
- All four SCP action names and the bucket ARN format are now confirmed in AWS docs (see 3.1). We did not run the SCP, so we have not seen it block anything.
- The boundary example uses the service prefixes `kms` and `logs` and wildcards. We checked that wildcards like `s3:*` are allowed in an `Action` (*IAM JSON policy elements: Action*). We did not check the prefixes `kms` and `logs`.
- Tools that check Terraform plans against rules (separate policy engines) are not covered by the AWS or Terraform docs we used. We did not pick one. The checks in 3.5 cover four rules on policy files only.
- The boundary example is only an example.

## Sources

See [SOURCES.md](../SOURCES.md).
