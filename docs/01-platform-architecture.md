# 01. Platform Architecture

**Cloud: AWS. IaC: Terraform.** Weight: 25%.

## What the task asks

Design the platform that runs Terraform: the state layout, the identity model, network access, runners, secrets, logs and disaster recovery. Use AWS and Terraform documentation as evidence.

## Contents

| # | Section | What it covers |
|---|---|---|
| 1.1 | Accounts and OUs | Virtual accounts and how they map to a real setup. Design, with a demo in one account |
| 1.2 | State layout | Layers, state buckets and keys, backend settings. Design and code (`modules/secure-state-bucket`, `stacks/`) |
| 1.3 | Identity model | Roles, separation of duties, state/identity matrix. Design and code (`modules/layer-roles`) |
| 1.4 | Network access | No VPC (Option B), with Option A as the alternative. Design |
| 1.5 | Runners and pipeline | CodePipeline and CodeBuild, four stages. Design |
| 1.6 | Secrets | Where secrets live, and how state and plan files are protected. Design |
| 1.7 | Logging and evidence | What evidence a change leaves. Design |
| 1.8 | Disaster recovery | State copy to a second Region, recovery steps. Design |
| 1.9 | Architecture diagram (required) | [docs/diagrams/architecture.md](diagrams/architecture.md) |
| 1.10 | Account vending | Two ways to create accounts, and our design. Design only |

## 1.1 Accounts and OUs

### The limit of this submission

The code we can deploy runs in **one** AWS account. We **pretend** to have separate accounts, using "virtual accounts". Each virtual account has its own state bucket, KMS key, IAM roles and name prefix. We do not show the real AWS account boundary (see README, assumption A-01).

### Virtual accounts

| Virtual account | Job in the design | Where it would sit in a real setup (design) |
|---|---|---|
| `platform` | Pipeline, state buckets for platform layers, module registry | Infrastructure / Deployments OUs |
| `nonprod` | Non-production workloads | Workloads OU |
| `prod` | Production workloads | Workloads OU |

### Why this shape

- An AWS account is a wall. Access between accounts is denied by default (AWS Whitepaper, *Organizing Your AWS Environment Using Multiple Accounts*, https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/organizing-your-aws-environment.html).
- AWS example OUs are Security, Sandbox, Infrastructure, Deployments, Workloads, Policy Staging, Exceptions and Suspended. The Infrastructure OU holds shared accounts such as Network, Identity, Monitoring and Operations Tooling (AWS Prescriptive Guidance, *Configuring account structure and OUs*, https://docs.aws.amazon.com/prescriptive-guidance/latest/designing-control-tower-landing-zone/account-structure.html).
- OUs should follow function or a shared set of controls. They should not copy the company org chart. Start simple and grow (AWS for Industries blog, *Defining an AWS multi-account strategy for a digital bank*, https://aws.amazon.com/blogs/industries/defining-an-aws-multi-account-strategy-for-a-digital-bank/; and *Configuring account structure and OUs* above).
- Production and non-production are kept apart, and the same account layout repeats in each environment (digital bank blog above).

Three virtual accounts is the smallest set that still shows platform, non-prod and prod apart. It keeps the repo small. More accounts would follow the same pattern.

## 1.2 State layout

### Layers

| Layer | What is in it | Where | Owner |
|---|---|---|---|
| `org` | OU structure, SCPs | `platform` only. SCPs cannot be shown working in one account, so this layer is mostly **design only**. | Central platform |
| `baseline` | Account basics: logging, KMS key, base roles, state bucket | `platform`, `nonprod`, `prod` | Central platform |
| `platform` | Pipeline, runners, module registry | `platform` only | Central platform |
| `workload` | Application resources | `nonprod`, `prod` | Product teams |

Product teams change only the `workload` layer, without asking the central platform group. This fixes the scenario problem where app teams need the platform group for every change.

### State layout

One state bucket per virtual account. The bucket tells you the account. The key tells you the layer and stack.

```
bucket: <prefix>-<virtual-account>-tfstate-<aws-account-id>-<region>
key:    <layer>/<stack>/terraform.tfstate
```

| Virtual account | Keys |
|---|---|
| `platform` | `org/…`, `baseline/…`, `platform/…` |
| `nonprod` | `baseline/…`, `workload/…` |
| `prod` | `baseline/…`, `workload/…` |

There is no global state. Each key has its own lock.

### Backend settings

From Terraform Docs, *Backend Type: s3* (https://developer.hashicorp.com/terraform/language/backend/s3) and AWS Prescriptive Guidance, *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html (https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html):

- `use_lockfile = true`: native S3 locking. A lock object `<key>.tflock` is stored next to the state. The argument defaults to `false`. The Terraform v1.10 changelog says "The s3 backend now supports S3 native state locking." The v1.11 changelog says "S3 native state locking is now generally available" and that the DynamoDB arguments are deprecated (*Terraform changelog v1.10 and v1.11*, https://github.com/hashicorp/terraform/blob/v1.10/CHANGELOG.md and https://github.com/hashicorp/terraform/blob/v1.11/CHANGELOG.md). So the stack requires Terraform 1.11 or later.
- `encrypt = true` with `kms_key_id`. The Terraform page says `encrypt` enables server-side encryption of the state and lock files, and that `kms_key_id` is the KMS key ARN used for that. With `kms_key_id`, Terraform needs `kms:Encrypt`, `kms:Decrypt` and `kms:GenerateDataKey` on the key. The sentence "Without `encrypt`, the backend ignores `kms_key_id`" is from the **AWS guide**, not from the Terraform page: AWS Prescriptive Guidance, *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html (the page says: "With `encrypt = true`, `kms_key_id` selects the key that encrypts the state. Without `encrypt`, the backend ignores `kms_key_id`.").
- `assume_role { role_arn = … }` in the backend, separate from the provider role.
- The bucket policy denies `s3:*` when `aws:SecureTransport` is `false`. S3 Versioning is on.

About DynamoDB: the Terraform S3 backend page says "DynamoDB-based locking is deprecated and will be removed in a future minor version." This design uses `use_lockfile` and no DynamoDB.

### Why separate states and buckets, not workspaces

- Use a separate backend per environment. The strongest split puts each environment's state bucket in its own account (AWS Prescriptive Guidance, *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html).
- Workspaces are "not appropriate for system decomposition or deployments requiring separate credentials and access controls" (Terraform Docs, *State: Workspaces*, https://developer.hashicorp.com/terraform/language/state/workspaces).

## 1.3 Identity model and state/identity matrix

### The rule

Keep the power to **see** a change apart from the power to **make** it. Keep each layer apart from every other layer. No single role can change every layer. Nobody who writes a change holds the role that applies it. This answers two constraints: "separation of duties and evidence" and "no single all-powerful execution role".

### Who and what

| Who | Identity | Can | Cannot |
|---|---|---|---|
| Developer (person) | Developer role | Push to the Git repo; read plan output | Apply; approve; edit the pipeline |
| Pipeline Plan step | CodeBuild service role `<vacct>-<layer>-plan` | Read the layer's state and resources | Change any resource |
| Approver (person) | Approver role | Approve or reject the approval action of one pipeline | Edit the pipeline; apply directly |
| Pipeline Apply step | CodeBuild service role `<vacct>-<layer>-apply` | Change resources in **its own layer only**; write its own state | Change any other layer |
| Break-glass (production only) | Break-glass role | Emergency change to production | Be used quietly: use raises an alert (design; see open items) |

There is one plan role and one apply role **per layer per virtual account**. So a pipeline can only reach the state and resources of its own layer.

### How the split is enforced

| Control | How | Evidence |
|---|---|---|
| Plan cannot change resources | The plan service role has read permissions only | AWS Docs, *Allow CodeBuild to interact with other AWS services*, https://docs.aws.amazon.com/codebuild/latest/userguide/setting-up-service-role.html (the service role is used for all actions on your behalf; give least privilege) |
| Another build project cannot use the role | Trust policy `codebuild.amazonaws.com` with condition `aws:SourceArn` set to the ARN of one CodeBuild project | same page (advised against the confused deputy problem) |
| State access is separate from resource access | Backend `assume_role { role_arn = … }` uses a state role that differs from the provider role | Terraform Docs, *Backend Type: s3*, https://developer.hashicorp.com/terraform/language/backend/s3; AWS Prescriptive Guidance, *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html |
| Production state is read-only except for the pipeline and break-glass | Bucket policy and role permissions on the `prod` state bucket | AWS Prescriptive Guidance, *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html |
| Only the approver can approve | `codepipeline:PutApprovalResult` goes only to the approver role, on `arn:aws:codepipeline:<region>:<account>:<pipeline-name>/<stage-name>/<action-name>` | AWS Docs, *permissions reference*, https://docs.aws.amazon.com/codepipeline/latest/userguide/permissions-reference.html |
| The approver cannot rewrite the gate | The approver role does not get `codepipeline:UpdatePipeline` | same page |

AWS has a managed policy `AWSCodePipelineApproverAccess`. AWS also says managed policies may not give least privilege, and advises customer managed policies (AWS Docs, *AWS managed policies for AWS CodePipeline*, https://docs.aws.amazon.com/codepipeline/latest/userguide/managed-policies.html). So this design uses a customer managed policy for one action.

### State/identity matrix

| Virtual account | Layer | State key | Plan role | Apply role | Approver | Owner |
|---|---|---|---|---|---|---|
| `platform` | `org` | `org/<stack>/terraform.tfstate` | `platform-org-plan` | `platform-org-apply` | Platform approver | Central platform |
| `platform` | `baseline` | `baseline/<stack>/terraform.tfstate` | `platform-baseline-plan` | `platform-baseline-apply` | Platform approver | Central platform |
| `platform` | `platform` | `platform/<stack>/terraform.tfstate` | `platform-platform-plan` | `platform-platform-apply` | Platform approver | Central platform |
| `nonprod` | `baseline` | `baseline/<stack>/terraform.tfstate` | `nonprod-baseline-plan` | `nonprod-baseline-apply` | Platform approver | Central platform |
| `nonprod` | `workload` | `workload/<stack>/terraform.tfstate` | `nonprod-workload-plan` | `nonprod-workload-apply` | Product team approver | Product team |
| `prod` | `baseline` | `baseline/<stack>/terraform.tfstate` | `prod-baseline-plan` | `prod-baseline-apply` | Platform approver | Central platform |
| `prod` | `workload` | `workload/<stack>/terraform.tfstate` | `prod-workload-plan` | `prod-workload-apply` | Product team approver **and** platform approver | Product team |

Each state key lives in the bucket of its virtual account (section 1.2).

The `org` layer is **design only**, because we cannot show SCPs working in one AWS account (README, assumption A-01).

### Known limits of this section

- **One account:** these roles are split by IAM rules, not by an AWS account wall. A person with broad permissions in the one real account could get around them.
- **No documented check that the committer cannot approve:** no document we read describes a CodePipeline way to stop the person who committed a change from approving it. Our backup control is the identity split above.
- **Lock object permissions:** the S3 backend page says that when `use_lockfile` is set, `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` are required on the lock file `<key>.tflock`, and that `s3:DeleteObject` is not required on the state file. `modules/layer-roles` follows this. **Unverified:** whether `terraform plan` needs `s3:PutObject` on the state object itself. The page lists Get and Put on the state key without saying which command needs which. We check this at deploy time.
- **Limiting resource permissions by layer:** we have not chosen how to limit an apply role to the resources of its own layer (name prefixes or tags).

## 1.4 Network access

Chosen: **Option B, CodeBuild without a VPC** (confirmed by the candidate). Option A is written down as the alternative we looked at.

### Goal

The runners (AWS CodeBuild) must reach what Terraform needs. Nobody connects in to the runners, and nobody needs to. We control access to state by identity, encryption and audit, not by network location.

### What a build must reach

| Where | Why | Path in this design |
|---|---|---|
| Amazon S3 (state buckets, pipeline artifact store) | Read and write state, the lock object, artifacts | CodeBuild default network (no VPC) |
| Public Terraform provider registry | Download providers during `terraform init` | CodeBuild default network (direct install) |
| AWS service APIs | Resources the provider manages | CodeBuild default network |
| GitHub | Source of the pipeline | The CodePipeline source action does this through the connection, not the build (see 1.5) |

We expect the CodeBuild default network to give this outbound access. The pages we read do not say so. We check it when we deploy the pipeline.

### Chosen design: Option B, no VPC

- The CodeBuild projects have no VPC setting. The pages we read say CodeBuild usually cannot reach resources in a VPC unless you give VPC settings. This design needs no VPC resources, so we set none.
- No NAT gateway, VPC, subnets, security groups or VPC endpoints are created.
- Providers are installed with the `direct` method.

### Controls that stand in for network limits

We cannot limit the state bucket to a VPC endpoint. So state protection depends on the controls from sections 1.2 and 1.3:

| Control | Section |
|---|---|
| Separate state bucket and KMS key per virtual account | 1.2 |
| Backend `assume_role`: state access is separate from resource access | 1.2, 1.3 |
| Plan and Apply roles per layer; role trust tied to one CodeBuild project | 1.3 |
| Encrypted transport only (bucket policy denies `s3:*` when `aws:SecureTransport` is `false`) | 1.2 |
| CloudTrail data events on state buckets, and an alert on unexpected lock deletion | 1.7 |
| S3 Versioning and restore | 1.8 |

### Alternative we looked at: Option A, CodeBuild in a VPC (not chosen)

- One VPC with public and private subnets in more than one Availability Zone, and a NAT gateway in a public subnet. CodeBuild projects use private subnets only, in their own subnets, with no inbound security group rules.
- An S3 gateway endpoint with an endpoint policy limited to the state and artifact buckets. The state bucket policy allows requests only through that endpoint (`aws:sourceVpce`), with an exception for the break-glass role.
- An optional provider mirror (`filesystem_mirror` or `network_mirror`, with `direct` excluded for those providers), so builds do not call the public registry.
- Why we did not choose it: the NAT gateway has a cost we did not check. The extra resources do not fit our time. The bucket policy that forces the endpoint also blocks Console access to the state bucket, so we would need a tested break-glass exception.
- What we give up: network limits on the state bucket and control of outbound traffic. In a regulated setting, Option A is the stronger design. It would be the goal when time and budget allow.

### Evidence

- By default CodeBuild cannot reach resources in a VPC. To turn it on, the project needs the VPC ID, subnet IDs and security group IDs. Best practices for a VPC build: public and private subnets with a NAT gateway in a public subnet; more than one Availability Zone; security groups with no inbound traffic to builds; separate subnets for builds; private subnets only. A NAT gateway or NAT instance is needed for public endpoints. An internet gateway cannot replace it. VPC connection from CodeBuild is not supported for shared VPCs (AWS Docs, *Use AWS CodeBuild with Amazon Virtual Private Cloud*, https://docs.aws.amazon.com/codebuild/latest/userguide/vpc-support.html).
- CodeBuild supports an interface VPC endpoint (AWS PrivateLink) `com.amazonaws.<region>.codebuild`. It is advised but not required. A NAT gateway is still needed for AWS services that do not support PrivateLink (AWS Docs, *Use VPC endpoints*, https://docs.aws.amazon.com/codebuild/latest/userguide/use-vpc-endpoints-with-codebuild.html).
- An S3 gateway endpoint has no extra charge. A bucket policy can require a certain endpoint with `aws:sourceVpce` or a VPC with `aws:sourceVpc`. Such a policy also blocks access through the AWS Management Console (AWS Docs, *Gateway endpoints for Amazon S3*, https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html).
- Providers are installed with the methods in the `provider_installation` block of the CLI configuration file: `direct`, `filesystem_mirror` and `network_mirror`. Each method takes `include` and `exclude` patterns. The page's example installs providers from one registry only from a filesystem mirror, and adds `direct { exclude = [...] }` for that registry (Terraform Docs, *Create a Terraform CLI configuration file*, https://developer.hashicorp.com/terraform/cli/config/config-file).

### Known limits of this section

- **No network limit on state.** Anyone with a credential that has state permissions can reach the state bucket from outside the runners. We rely on identity, encryption and audit only.
- **Outbound traffic is not controlled.** A build can reach any internet address that the CodeBuild default network allows.
- **Provider supply chain.** Providers are downloaded straight from the public registry. A provider mirror is not part of the chosen design.
- **Default network assumption.** We check the outbound access of the CodeBuild default network at deploy time (see above).

## 1.5 Runners and pipeline

### Choice

The runner uses AWS services: **AWS CodePipeline** controls the flow and **AWS CodeBuild** runs Terraform. So the execution platform stays on provider-native services.

### One pipeline per layer per virtual account

The pipeline resources (CodePipeline, CodeBuild projects, approval topic) sit in the `platform` virtual account. Each Plan and Apply step works on its target virtual account through that target's own role (design clarification, confirmed by the candidate; see [architecture diagram](diagrams/architecture.md)).

Pipeline name: `<virtual-account>-<layer>` (for example `prod-workload`). Four stages:

| # | Stage | Service | Identity | What happens |
|---|---|---|---|---|
| 1 | Source | CodePipeline source action `CodeStarSourceConnection` | Connection to GitHub (via GitHub App) | The pipeline starts when the chosen branch changes |
| 2 | Plan | CodeBuild | `<vacct>-<layer>-plan` | Starts Terraform and makes a plan. The plan is kept as the stage artifact |
| 3 | Approval | CodePipeline manual approval (stage `Approval`, action `ManualApproval`) | Approver role | The pipeline stops until the approver approves or rejects |
| 4 | Apply | CodeBuild | `<vacct>-<layer>-apply` | Applies the plan that was approved |

Design goal: what is approved is what is applied. The Apply stage uses the output of the Plan stage, not a fresh plan. The exact Terraform commands to save and apply a plan file are **not yet verified** (see open items).

### Evidence for each stage

- **Source.** A GitHub repo is connected through AWS CodeConnections (console provider **GitHub (via GitHub App)**, CLI provider `GitHub`). The action is `CodeStarSourceConnection` (Category `Source`, Owner `AWS`, Version `1`) with `ConnectionArn`, `FullRepositoryId` (`owner/repo`), `BranchName`, and optionally `OutputArtifactFormat` and `DetectChanges`. The pipeline service role needs `codeconnections:UseConnection` and `codestar-connections:UseConnection`. For a repo in a GitHub organization, the person who creates the connection must be the organization owner. Otherwise it is the repo owner. The page says the source action gets code changes when a pipeline is run by hand or when a webhook event is sent from the source provider. We did not set up or test this (AWS Docs, *CodeStarSourceConnection for Bitbucket Cloud, GitHub, GitHub Enterprise Server, GitLab.com, and GitLab self-managed actions*, https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodestarConnectionSource.html).
- **Other source option.** The same action supports GitLab.com (provider `GitLab`) and GitLab self-managed (`GitLabSelfManaged`). So the platform is not tied to one Git host (same page; AWS Docs, *GitLab.com connections*, https://docs.aws.amazon.com/codepipeline/latest/userguide/connections-gitlab.html).
- **Plan and Apply.** CodeBuild uses its service role for all actions on your behalf. A role with too many permissions can raise privileges. So each project has its own least-privilege role (AWS Docs, *Allow CodeBuild to interact with other AWS services*, https://docs.aws.amazon.com/codebuild/latest/userguide/setting-up-service-role.html).
- **Approval.** CodePipeline manual approval stops the pipeline until a person with the right IAM permission approves or rejects. A rejection, or no answer in seven days, fails the action and the pipeline does not go on. Approval can notify an Amazon SNS topic, which must be in the same Region as the pipeline (AWS Docs, *Add a manual approval action to a stage*, https://docs.aws.amazon.com/codepipeline/latest/userguide/approvals.html).
- **Two runs at once.** Terraform locks state for every operation that can write it. If locking fails, Terraform does not continue (Terraform Docs, *State: Locking*, https://developer.hashicorp.com/terraform/language/state/locking). With S3 native locking, a second run fails with `Error acquiring the state lock` and shows who holds the lock (AWS Prescriptive Guidance, *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html). Terraform does accept `-lock-timeout` (Terraform Docs, *terraform plan command reference* and *terraform apply command reference*; see `docs/05`, 5.2).

### Known limits of this section

- **Manual connection step.** A connection made through the AWS CLI, CloudFormation or the AWS provider starts in `PENDING` status. You must finish the handshake with the Git host in the AWS Console. You cannot update a pending connection with the AWS CLI. The pipeline does not start until the connection is `AVAILABLE` (AWS Docs, *Update a pending connection*, https://docs.aws.amazon.com/dtconsole/latest/userguide/connections-update.html; AWS provider docs for `aws_codestarconnections_connection`, https://github.com/hashicorp/terraform-provider-aws/blob/main/website/docs/r/codestarconnections_connection.html.markdown).
- **Approval timeout.** An approval with no answer in seven days fails the action. The change must be started again.
- **Region availability.** Connections are not available in several AWS Regions (for example Hong Kong, Jakarta, Osaka, Cape Town, Bahrain, UAE, Spain, Zurich). Check the chosen Region against the list on the AWS Docs page above.
- **Network access of runners:** no VPC (section 1.4, Option B).

## 1.6 Secrets

### The rule

The platform keeps as few secrets as it can. Identity comes from IAM roles with short-lived credentials, not from stored keys. CodeBuild uses its service role for all actions on your behalf (AWS Docs, *Allow CodeBuild to interact with other AWS services*, https://docs.aws.amazon.com/codebuild/latest/userguide/setting-up-service-role.html). The Terraform backend uses `assume_role` (Terraform Docs, *Backend Type: s3*, https://developer.hashicorp.com/terraform/language/backend/s3).

### Which secrets exist and where they live

| Item | How we handle it | Evidence |
|---|---|---|
| Credentials to AWS | None stored. The pipeline assumes roles | Service role and backend `assume_role` (above) |
| Access to the Git host | Approved once in the AWS Console through the connection handshake. Not stored in the repo or in build variables | AWS Docs, *Update a pending connection*, https://docs.aws.amazon.com/dtconsole/latest/userguide/connections-update.html |
| Workload app secrets (for example a database password) | Kept in AWS Secrets Manager or Systems Manager Parameter Store. The build reads them at run time with the `secrets-manager` or `parameter-store` mapping | AWS Docs, *Build specification reference for CodeBuild*, https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html |
| Terraform variable files | `*.tfvars` is kept out of Git (`.gitignore`) | Repo `.gitignore` |

### Rules from the docs

- Plain-text environment variables are strongly discouraged for secret values. The CodeBuild console and the AWS CLI can show them in plain text. Use `parameter-store` or `secrets-manager` instead (*Build specification reference for CodeBuild*).
- CodeBuild hides AWS access key IDs, Parameter Store strings and Secrets Manager strings in logs. But the hiding matches the exact stored value. If a command changes a secret (for example Base64), it can show up in logs (same page).
- To read Parameter Store values, the CodeBuild service role needs the `ssm:GetParameters` action (same page). We did not read the matching Secrets Manager permission.

### State and plan files are sensitive

- State holds resource IDs and all resource attributes. It may hold first passwords of databases. Treat state as secret. Use remote storage with encryption at rest (the S3 backend encrypts when `encrypt` is on, and uses TLS). Use IAM policies and logging to spot bad access (Terraform Docs, *Manage sensitive data in your configuration*, https://developer.hashicorp.com/terraform/language/manage-sensitive-data).
- A saved plan file may hold secret values in plain text. The page says "it will be saved in cleartext in the plan file" and "You should therefore treat any saved plan files as potentially-sensitive artifacts" (Terraform Docs, *terraform plan command reference*, https://developer.hashicorp.com/terraform/cli/commands/plan). The pipeline artifact store holds the plan between Plan and Apply, so it must be protected like state. How to protect it is not designed here.
- The Terraform docs we read do not describe encrypting state or plan files in Terraform itself. They say "You can encrypt your state at rest, but the encryption method depends on your specific backend" (*Manage sensitive data in your configuration*). For S3 we use `encrypt = true` with `kms_key_id` (1.2).

### Known limits

- Secret rotation is not designed.
- We did not read the Secrets Manager permissions for the CodeBuild role, or how to encrypt the pipeline artifact store.

## 1.7 Logging and evidence

### What evidence a change leaves

| Question an auditor asks | Where the evidence is | Detail |
|---|---|---|
| What changed and who proposed it | Git commit; the pipeline run trigger | CodePipeline events carry an `execution-trigger` with the commit ID and author for sources connected to a repo (AWS Docs, *Monitoring CodePipeline events*, https://docs.aws.amazon.com/codepipeline/latest/userguide/detect-state-changes-cloudwatch-events.html) |
| What was going to happen | The plan made by the Plan stage | Plan artifact (treat as secret; `docs/01`, 1.6) |
| Who approved, when, and why | Approval action result with a summary comment | The approver gives a summary comment and Approved or Rejected (AWS Docs, *Add a manual approval action to a stage*, https://docs.aws.amazon.com/codepipeline/latest/userguide/approvals.html) |
| What actually ran | Build logs | The CodeBuild service role policy includes the CloudWatch Logs actions `logs:CreateLogGroup`, `logs:CreateLogStream` and `logs:PutLogEvents` (*Allow CodeBuild to interact with other AWS services*) |
| Who touched state | CloudTrail data events on the state buckets | Limited with an advanced event selector; log file validation on (AWS Prescriptive Guidance, *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html) |
| Was anything unsafe done | Alert when a non-pipeline principal deletes a `.tflock` | EventBridge rule on CloudTrail events (*Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html) |

### Pipeline events

CodePipeline sends EventBridge events for pipeline, stage and action runs. The detail types are `CodePipeline Pipeline Execution State Change`, `CodePipeline Stage Execution State Change` and `CodePipeline Action Execution State Change`. Pipeline states include `STARTED`, `SUCCEEDED`, `FAILED`, `SUPERSEDED`, `STOPPED`, `CANCELED` and `RESUMED`. For approval actions, `FAILED` means the reviewer rejected it, or the setup was wrong (*Monitoring CodePipeline events*). These events feed the SLIs in `docs/06`.

### Known limits

- Log retention, protection of the log destination and a separate log archive account are not designed. In this one-account submission, an administrator of the account could change logs.
- We did not read which CloudTrail event records an approval, or where CodeBuild logs go by default. The evidence table lists only sources that the pages we read describe.
- CloudTrail data events are off by default and cost money. We limit them to the state buckets (*Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html).

## 1.8 Disaster recovery

### What must be recoverable

| Asset | How to recover | Evidence |
|---|---|---|
| State | Restore an older object version; copy to a second Region | S3 Versioning and AWS Backup on the state bucket (AWS *Backend best practices*, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html); S3 replication (below) |
| Pipelines and roles | Rebuild from code in Git by applying the `platform` and `baseline` layers | Infrastructure is code (`docs/01`, 1.2) |
| Git connection | Create it again and approve it in the Console | A pending connection must be finished in the Console. You cannot update it with the AWS CLI (*Update a pending connection*) |
| Modules | Git tags | `docs/02`, 2.3 |

### State copy (replication)

Amazon S3 replication copies objects, not at the same moment, between buckets in the same or different AWS Regions. Live replication does not copy objects that existed before it was set up. Batch Replication copies existing objects when you ask. Cross-Region Replication copies across Regions. S3 Replication Time Control copies 99.99 percent of new objects within 15 minutes, with a service-level agreement (AWS Docs, *Replicating objects within and across Regions*, https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html).

Design: copy each state bucket to a bucket in a second Region. Use S3 Replication Time Control if the recovery point goal needs it. We did not read the replication requirements page (including versioning and KMS points). Check it before building.

### Recovery steps

1. Declare an incident and freeze the pipelines (`codepipeline:DisableStageTransition` exists for this; *permissions reference*).
2. Point the backend at the copied bucket in the second Region.
3. Create the Git connection again in the second Region and finish the handshake in the Console. Connections are not available in some Regions (*GitLab.com connections*, https://docs.aws.amazon.com/codepipeline/latest/userguide/connections-gitlab.html). Check the second Region against that list.
4. Remove any stale `.tflock` object with the force-unlock steps (`docs/05`, 5.2).
5. Run a plan on every stack. A clean plan shows that state matches reality.

### Known limits

- The recovery point goal depends on copy delay, because copying is not instant. We claim no recovery time goal.
- We have not chosen the second Region.
- Copied lock objects after a failover are a design worry that we have not tested.

## 1.10 Account vending

Design only. The constraint says the platform "must support controlled module evolution and account vending". Module evolution is in `docs/02`. This section covers vending: making a new AWS account in a repeatable, reviewed way, and bringing it under the platform.

### What the docs say about the two ways to create accounts

| | AFT (Account Factory for Terraform) | AWS Organizations (create account) |
|---|---|---|
| How a request is made | An account request Terraform file, started by a `git push` | The console, or the `organizations:CreateAccount` permission through API or CLI |
| Needs | An existing AWS Control Tower landing zone. A separate "AFT management account" runs AFT | An organization. You sign in to the management account |
| Order of work | Requests are processed first-in-first-out. Provisioning runs in the Control Tower management account. Then customization pipelines run for each vended account | One step: the account is created, then you move it |
| After creation | Global customizations run in a pipeline for each vended account. You can add customizations for all accounts, a set, or one account. It stores account metadata and audit history, and applies account tags | New accounts are created in the **root** of the organization. Move them to an OU afterwards. Policies attached to the root apply at once |
| Things to watch | The AFT pipeline "is not intended" for app resources. It is only for provisioning and customizing accounts | The role `OrganizationAccountAccessRole` is created automatically. It gives users and roles in the management account **full administrative control** of the member account (subject to SCPs). The email must be new, because it becomes the root user name. In a Control Tower organization, create accounts in Control Tower, or they are not enrolled |
| Sources | AWS Docs, *Overview of AWS Control Tower Account Factory for Terraform*, https://docs.aws.amazon.com/controltower/latest/userguide/aft-overview.html; *AFT Architecture*, https://docs.aws.amazon.com/controltower/latest/userguide/aft-architecture.html | AWS Docs, *Creating a member account in an organization with AWS Organizations*, https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts_create.html |

The AFT overview page says AFT supports HCP Terraform, Terraform Enterprise and Terraform Community Edition. It also says AFT can use AWS CodeCommit, or other version control through AWS CodeConnections.

### Design in this submission

1. **Request.** A team opens a pull request that adds a request file for the new account: account name, owner, OU, virtual-account type (`nonprod` or `prod`) and a unique email address.
2. **Review.** The central platform group reviews it. Teams cannot approve their own vending request (same approver rule as `docs/01`, 1.3).
3. **Create.** The `org` layer pipeline creates the account (Plan, Approval, Apply, as in 1.5). The apply role for this layer gets only the account-creation permissions it needs. We know `organizations:CreateAccount` is required. We did not list any other permission, so the full set is **unverified**.
4. **Place.** Move the account to the right OU (from the root). SCPs from the OU apply (`docs/03`, 3.1).
5. **Baseline.** Apply the `baseline` layer in the new account: state bucket (`modules/secure-state-bucket`), KMS key, and plan and apply roles (`modules/layer-roles`). This is the same code as for `nonprod` and `prod` in this repo, so a new account is a new stack that calls two existing modules.
6. **Tag and record.** Set the tags `VirtualAccount`, `Layer` and `Owner` (`docs/06`, 6.4). Add the account to the register (`docs/04`, 4.1).
7. **Hand over.** The product team owns the `workload` layer of its account (matrix, 1.3).

**Which option we recommend.** If the organization already uses Control Tower, use AFT, because AWS says to create accounts in Control Tower in that case, and AFT adds customizations, metadata and audit history. If it does not use Control Tower, use the Organizations route through the `org` layer. AFT needs an existing Control Tower landing zone. Both routes end with step 5.

**The risk to manage:** the automatic `OrganizationAccountAccessRole` is a full-administrator role. It conflicts with "no all-powerful role". The design uses it only to bootstrap the baseline, with an SCP and an alert on its use (alert design not yet researched). Whether it can be removed or limited after bootstrap is **unverified**.

### What we can and cannot show

| Can show (one account) | Cannot show |
|---|---|
| Step 5: the baseline modules and their tests | Creating a real account (we have one account and no organization) |
| The request and review flow as a pull request and pipeline | SCP effect, OU placement, per-account bills |

### Known limits

- Design only. No account is created.
- The permission set for the `org` apply role beyond `organizations:CreateAccount` is **unverified**.
- We did not read the *AFT account provisioning pipeline* page or the Organizations CLI procedure.

## Open items

- Sections 1.6, 1.7 and 1.8 are shorter than 1.1 to 1.5. Their known limits list what is not designed, for example secret rotation, log retention and the choice of the second Region.
- The diagram does not yet show secrets, logging or disaster recovery parts.
- The docs we read describe the Terraform commands to save and apply a plan file in the pipeline (`terraform plan -out`, `terraform apply <plan file>`). We have not written or run the exact buildspec commands.
- We have not researched how a break-glass role use raises an alert.
- Versions: the stack needs Terraform 1.11 or later (`use_lockfile` is generally available from 1.11). The modules need 1.7 or later (`mock_provider`). Tests ran on Terraform v1.17.1, first with a downloaded binary and again with the v1.17.1 installed on the author's machine.

## Sources

See [SOURCES.md](../SOURCES.md).
