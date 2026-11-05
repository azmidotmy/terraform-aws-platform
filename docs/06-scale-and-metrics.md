# 06. Scale and Metrics

**Cloud: AWS. IaC: Terraform.** Weight: 10%.

## What the task asks

Define the service model, what teams can do alone, the SLIs, cost tracking, and measures of how much teams use the platform and how safe it is. Use AWS data as evidence.

## 6.1 Service model

The central platform group gives a product, not a ticket queue.

| The platform gives | Product teams use |
|---|---|
| Versioned modules with tests (`docs/02`) | Pinned module versions in their stacks |
| One pipeline per layer and state key (`docs/01`, 1.5) | A pull request that starts a plan |
| Guardrails, boundaries and an exception process (`docs/03`) | Choices inside the boundary |
| Migration waves and support (`docs/04`) | Joining a wave |
| Runbooks for failures (`docs/05`) | Follow the runbook first, then ask for help |

## 6.2 What teams can do alone

| Teams can, without the platform group | Teams cannot |
|---|---|
| Change their `workload` layer through their own pipeline | Change the `org`, `baseline` or `platform` layers |
| Choose module inputs that the module validation accepts | Change a module's validation or the permissions boundary |
| Approve their own non-production changes with a second team member | Approve production changes alone. Production needs the approver role (and the platform approver, `docs/01`, matrix) |
| Ask for an exception through the lifecycle (`docs/03`, 3.4) | Apply outside the pipeline, except through break-glass |

## 6.3 SLIs

Each SLI uses a data source that the AWS docs describe. We set targets (SLOs) after a baseline period, because there is no baseline yet.

| SLI | Meaning | Data source (documented) |
|---|---|---|
| Change success rate | Successful pipeline runs divided by finished pipeline runs | CodePipeline events in Amazon EventBridge: detail type `CodePipeline Pipeline Execution State Change`, state `SUCCEEDED` or `FAILED` (AWS Docs, *Monitoring CodePipeline events*, https://docs.aws.amazon.com/codepipeline/latest/userguide/detect-state-changes-cloudwatch-events.html) |
| Build success rate | `SucceededBuilds` divided by `Builds` for the apply projects | CodeBuild CloudWatch metrics `Builds`, `SucceededBuilds`, `FailedBuilds`, `Duration` (AWS Docs, *View CodeBuild metrics*, https://docs.aws.amazon.com/codebuild/latest/userguide/monitoring-metrics.html) |
| Lead time | Time from start of a run to success | Event `start-time` and event `time` for the same `execution-id` (*Monitoring CodePipeline events*) |
| Approval wait | How long an approval stays open | Action events for the `Approval` category: `STARTED` and the final state (*Monitoring CodePipeline events*) |
| Approval reject or timeout rate | Approvals in state `FAILED` divided by all approvals | For approvals, `FAILED` means the reviewer rejected it, or the setup was wrong. An approval nobody answers fails after seven days (*Monitoring CodePipeline events*; *Add a manual approval action to a stage*) |

`Duration` is a project metric that CloudWatch shows for each CodeBuild project. One rule can catch failed approvals in all pipelines. Use an event pattern with `CodePipeline Action Execution State Change`, `state` `FAILED` and `type.category` `Approval` (*Monitoring CodePipeline events*).

## 6.4 Cost tracking

- A cost allocation tag is a tag key and value. Once you turn it on, it groups costs in the cost allocation report and in Cost Explorer. You must turn on user-defined tags yourself. Tags can take up to 24 hours to show. Do not put secrets in tags (AWS Docs, *Organizing and tracking costs using AWS cost allocation tags*, https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html).
- Only the management account of an organization, or an account that is not in an organization, can use the cost allocation tag manager (same page). This submission uses a standalone account, so the manager works.
- Tag keys used by the stacks and modules in this repo: `VirtualAccount`, `Layer`, `Owner` (see `stacks/nonprod/baseline`).
- In a real multi-account setup, the account is the main cost boundary (AWS Control Tower docs, *AWS multi-account strategy*, https://docs.aws.amazon.com/controltower/latest/userguide/aws-multi-account-landing-zone.html: "An account is the only way to separate items at a billing level"). Tags add team and layer detail.
- Cannot show here: cost per account, because this submission has one account.

## 6.5 Adoption and safety measures

| Measure | Type | How to get it |
|---|---|---|
| Stacks on the platform pipeline divided by stacks in the register | Adoption | Register from discovery (`docs/04`, 4.1) and the pipeline list |
| Stacks using a pinned module tag divided by stacks using a fork | Adoption | Scan of module sources (`docs/02`, 2.2) |
| Teams that changed production without a ticket to the platform group | Adoption | Pull requests on `workload` layers |
| Changes applied outside the pipeline | Safety | CloudTrail data events on state buckets and API activity (design, `docs/01`, 1.7) |
| Break-glass role uses | Safety | CloudTrail (alert design not yet researched) |
| Manual `.tflock` deletes by non-pipeline principals | Safety | EventBridge rule on CloudTrail data events (AWS *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html) |
| Plans with a replace or delete that were rejected at approval | Safety | Approval `FAILED` events plus rejection comments |
| Exceptions past their end date | Governance | Exception register (`docs/03`, 3.4). The test in `policies/exceptions` fails when an exception is past its end date |

## Known limits

- There is no baseline, so we state no SLO values.
- The metrics come from documented events and metrics. The dashboards and alarms are not built in this submission.
- Counting lock clashes needs a data source (for example build logs) that is not designed yet.

## Sources

See [SOURCES.md](../SOURCES.md).
