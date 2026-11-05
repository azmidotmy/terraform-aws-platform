# Sources

Every AWS and Terraform page used in this submission. The documents in `docs/` cite the page name and the URL where a statement is used. Where a statement could not be confirmed from a page, the document marks it **unverified**.

How the pages were checked: for the syntax and the quoted phrases that matter, the text of the page was fetched and searched, not only the URL (see the Validation section of the [README](README.md)).

**Task(s) column:** which task documents (and code for that task) cite the page. 1 = Platform architecture, 2 = Module product model, 3 = Governance, 4 = Migration, 5 = Failure scenario, 6 = Scale and metrics. It is worked out from where the page URL appears in `docs/` and in the sample code (modules count for task 2, `policies/` for task 3, `examples/` for task 4, `stacks/` for task 1). "Background" means the page was read but no task document cites it.

| # | Source | Page / Syntax | Used for | Task(s) |
|---|---|---|---|---|
| 1 | Terraform Docs | *Backend Type: s3*, https://developer.hashicorp.com/terraform/language/backend/s3 (`use_lockfile`, `assume_role`, `kms_key_id`, `encrypt`) | State backend | 1, 2 |
| 2 | Terraform Docs | *State*, https://developer.hashicorp.com/terraform/language/state | State overview | 1, 5 |
| 3 | Terraform Docs | *State: Locking*, https://developer.hashicorp.com/terraform/language/state/locking | Locking, failure scenario | 1, 5 |
| 4 | Terraform Docs | *State: Workspaces*, https://developer.hashicorp.com/terraform/language/state/workspaces | State separation | 1 |
| 5 | Terraform Docs | *The terraform_remote_state Data Source*, https://developer.hashicorp.com/terraform/language/state/remote-state-data | Cross-stack outputs | Background (read, not cited in a task) |
| 6 | Terraform Docs | *Manage sensitive data in your configuration*, https://developer.hashicorp.com/terraform/language/manage-sensitive-data (state and plan files hold secrets; encrypt state at rest by backend) | Secrets, state protection | 1 |
| 7 | AWS Docs | *Backend best practices* (Terraform AWS provider), https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html | State backend | 1, 3, 4, 5, 6 |
| 8 | AWS Docs | *Organizing Your AWS Environment Using Multiple Accounts*, https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/organizing-your-aws-environment.html | Account structure | 1 |
| 9 | AWS Docs | *AWS multi-account strategy for your AWS Control Tower landing zone*, https://docs.aws.amazon.com/controltower/latest/userguide/aws-multi-account-landing-zone.html | OU design | 6 |
| 10 | AWS Docs | *Configuring account structure and OUs*, https://docs.aws.amazon.com/prescriptive-guidance/latest/designing-control-tower-landing-zone/account-structure.html | OU design | 1, 3 |
| 11 | AWS Docs | *Overview of AWS Control Tower Account Factory for Terraform*, https://docs.aws.amazon.com/controltower/latest/userguide/aft-overview.html | Account vending | 1 |
| 12 | AWS Docs | *Creating an organization with AWS Organizations*, https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_org_create.html | Organization setup | Background (read, not cited in a task) |
| 13 | AWS Blog | *Defining an AWS multi-account strategy for a digital bank*, https://aws.amazon.com/blogs/industries/defining-an-aws-multi-account-strategy-for-a-digital-bank/ (read in full) | Regulated-industry OU and account structure | 1 |
| 14 | Terraform Docs | *terraform test command reference*, https://developer.hashicorp.com/terraform/cli/commands/test (`terraform test`, default `tests` directory, `-test-directory`) | Module tests | 2 |
| 15 | Terraform Docs | *Dependency Lock File (.terraform.lock.hcl)*, https://developer.hashicorp.com/terraform/language/files/dependency-lock (`.terraform.lock.hcl`, `terraform init -upgrade`) | Provider upgrades | 2, 5 |
| 16 | Terraform Docs | *Terraform changelog v1.10*, https://github.com/hashicorp/terraform/blob/v1.10/CHANGELOG.md ("The s3 backend now supports S3 native state locking.") | Version of S3 native locking | 1 |
| 17 | Terraform Docs | *Terraform changelog v1.7*, https://github.com/hashicorp/terraform/blob/v1.7/CHANGELOG.md (`mock_provider`) | Version of provider mocking | 2 |
| 18 | AWS Docs | *Creating a member account in an organization with AWS Organizations*, https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts_create.html | Account vending (design) | 1 |
| 19 | AWS Docs | *Add a manual approval action to a stage*, https://docs.aws.amazon.com/codepipeline/latest/userguide/approvals.html | Production approval | 1, 5 |
| 20 | AWS Docs | *Allow CodeBuild to interact with other AWS services*, https://docs.aws.amazon.com/codebuild/latest/userguide/setting-up-service-role.html (service role, `aws:SourceArn`, `aws:SourceAccount`) | Runner identity | 1, 2 |
| 21 | AWS Docs | *Identity and access management for AWS CodePipeline*, https://docs.aws.amazon.com/codepipeline/latest/userguide/security-iam.html | Pipeline identity | Background (read, not cited in a task) |
| 22 | AWS Docs | *GitLab.com connections*, https://docs.aws.amazon.com/codepipeline/latest/userguide/connections-gitlab.html (provider `GitLab`, `create-connection`, `PENDING` status) | Alternative pipeline source (GitLab) | 1 |
| 23 | AWS Docs | *CodeStarSourceConnection for Bitbucket Cloud, GitHub, GitHub Enterprise Server, GitLab.com, and GitLab self-managed actions*, https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodestarConnectionSource.html (`ConnectionArn`, `FullRepositoryId`, `BranchName`, `codeconnections:UseConnection`; GitHub via GitHub App) | Pipeline source action (GitHub) | 1 |
| 24 | AWS Docs | *permissions reference* (CodePipeline), https://docs.aws.amazon.com/codepipeline/latest/userguide/permissions-reference.html (`codepipeline:PutApprovalResult`) | Approval separation | 1, 3, 5 |
| 25 | AWS Docs | *Use AWS CodeBuild with Amazon Virtual Private Cloud*, https://docs.aws.amazon.com/codebuild/latest/userguide/vpc-support.html | Runner network | 1 |
| 26 | AWS Docs | *Use VPC endpoints* (CodeBuild), https://docs.aws.amazon.com/codebuild/latest/userguide/use-vpc-endpoints-with-codebuild.html | Runner network | 1 |
| 27 | AWS Docs | *Gateway endpoints for Amazon S3*, https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html (`aws:sourceVpce`) | State bucket access path | 1 |
| 28 | Terraform Docs | *Create a Terraform CLI configuration file*, https://developer.hashicorp.com/terraform/cli/config/config-file (`provider_installation`, `filesystem_mirror`, `network_mirror`) | Provider mirror | 1 |
| 29 | Terraform Docs | *Import resources overview*, https://developer.hashicorp.com/terraform/language/import (`import` block: `to`, `id`) | Migration | 4, 5 |
| 30 | Terraform Docs | *Refactor modules*, https://developer.hashicorp.com/terraform/language/modules/develop/refactoring (`moved` block: `from`, `to`) | Migration, module compatibility | 2, 4 |
| 31 | Terraform Docs | *terraform state mv command reference*, https://developer.hashicorp.com/terraform/cli/commands/state/mv (`-dry-run`) | Migration | 4 |
| 32 | Terraform Docs | *Standard Module Structure*, https://developer.hashicorp.com/terraform/language/modules/develop/structure | Module standard | 2 |
| 33 | Terraform Docs | *module block reference*, https://developer.hashicorp.com/terraform/language/block/module (`?ref=`, `version`) | Module versioning | 2 |
| 34 | Terraform Docs | *Provider Requirements*, https://developer.hashicorp.com/terraform/language/providers/requirements (`required_providers`) | Module and stack | 2, 5 |
| 35 | Terraform Docs | *Validate your infrastructure in Terraform's configuration language*, https://developer.hashicorp.com/terraform/language/validate (`validation`, `precondition`, `check`) | Governance, module interface | 2, 3 |
| 36 | Terraform Docs | *terraform force-unlock command reference*, https://developer.hashicorp.com/terraform/cli/commands/force-unlock (`terraform force-unlock LOCK_ID`) | Failure scenario | 5 |
| 37 | Terraform Docs | *terraform plan command reference*, https://developer.hashicorp.com/terraform/cli/commands/plan (`-out`, `-detailed-exitcode`, `-lock-timeout`, `-refresh-only`) | Pipeline, migration, failure scenario | 1, 4, 5 |
| 38 | Terraform Docs | *terraform apply command reference*, https://developer.hashicorp.com/terraform/cli/commands/apply (saved plan, `-lock-timeout`) | Pipeline, failure scenario | 5 |
| 39 | AWS Docs | *Service control policies (SCPs)*, https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html | Governance | 3 |
| 40 | AWS Docs | *Service control policy examples*, https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_examples.html | Governance | 3 |
| 41 | AWS Docs | *Permissions boundaries for IAM entities*, https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html | Governance | 3 |
| 42 | AWS Docs | *What is AWS Resource Explorer?*, https://docs.aws.amazon.com/resource-explorer/latest/userguide/welcome.html | Migration discovery | 4 |
| 43 | AWS Docs | *Replicating objects within and across Regions*, https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html | Disaster recovery | 1 |
| 44 | AWS Docs | *Organizing and tracking costs using AWS cost allocation tags*, https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html | Cost allocation | 6 |
| 45 | AWS Docs | *Monitoring CodePipeline events*, https://docs.aws.amazon.com/codepipeline/latest/userguide/detect-state-changes-cloudwatch-events.html | Metrics, logging | 1, 6 |
| 46 | AWS Docs | *View CodeBuild metrics*, https://docs.aws.amazon.com/codebuild/latest/userguide/monitoring-metrics.html | Metrics | 6 |
| 47 | AWS Docs | *Build specification reference for CodeBuild*, https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html (`secrets-manager`, `parameter-store`) | Secrets | 1 |
| 48 | AWS Docs | *Update a pending connection*, https://docs.aws.amazon.com/dtconsole/latest/userguide/connections-update.html | Pipeline source limitation | 1 |
| 49 | AWS Docs | *AWS managed policies for AWS CodePipeline*, https://docs.aws.amazon.com/codepipeline/latest/userguide/managed-policies.html | Approver policy | 1 |
| 50 | AWS provider docs | `aws_s3_bucket`, `aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_public_access_block` (hashicorp/terraform-provider-aws, `website/docs/r/`) | Sample module | 1, 2 |
| 51 | AWS provider docs | `aws_codestarconnections_connection`, https://github.com/hashicorp/terraform-provider-aws/blob/main/website/docs/r/codestarconnections_connection.html.markdown | Pipeline source limitation | 1 |
| 52 | AWS Docs | *SCP syntax*, https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_syntax.html (`Resource`, `Action`, `Condition` supported in Allow and Deny) | SCP example | 3 |
| 53 | AWS Docs | *Policy actions for Amazon S3*, https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-with-s3-policy-actions.html (`s3:DeleteBucket`, `s3:PutBucketVersioning`) | SCP example | 3 |
| 54 | AWS Docs | *DeleteBucket* (S3 API), https://docs.aws.amazon.com/AmazonS3/latest/API/API_DeleteBucket.html | SCP example | 3 |
| 55 | AWS Docs | *Identity-based policy examples for AWS CloudTrail*, https://docs.aws.amazon.com/awscloudtrail/latest/userguide/security_iam_id-based-policy-examples.html (`cloudtrail:StopLogging`) | SCP example | 3 |
| 56 | AWS Docs | *DeleteTrail* (CloudTrail API), https://docs.aws.amazon.com/awscloudtrail/latest/APIReference/API_DeleteTrail.html | SCP example (operation exists; IAM string unverified) | 3 |
| 57 | AWS Docs | *IAM JSON policy elements: Action*, https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_action.html (wildcards, service prefix) | Policy examples | 3 |
| 58 | Terraform Docs | *Backend block configuration overview*, https://developer.hashicorp.com/terraform/language/backend (changing backend, partial configuration, backing up state before migrating) | Migration | 1, 2, 4 |
| 59 | Terraform Docs | *terraform init command reference*, https://developer.hashicorp.com/terraform/cli/commands/init (`-migrate-state`, `-force-copy`, `-reconfigure`, `-backend-config`) | Migration | 4 |
| 60 | Terraform Docs | *Backend Type: local*, https://developer.hashicorp.com/terraform/language/backend/local | Migration | 4 |
| 61 | AWS Docs | *AFT Architecture*, https://docs.aws.amazon.com/controltower/latest/userguide/aft-architecture.html (order of operations, first-in-first-out) | Account vending | 1 |
| 62 | Terraform Docs | *Tests - Configuration Language*, https://developer.hashicorp.com/terraform/language/tests (`.tftest.hcl`, `run`, `assert`, `command = plan`, "Terraform v1.7.0 introduced the ability to mock data") | Module tests | 2, 3 |
| 63 | Terraform Docs | *Tests - Provider Mocking*, https://developer.hashicorp.com/terraform/language/tests/mocking (`mock_provider`, `override_during`) | Module tests | 2 |
| 64 | Terraform Docs | *import block reference*, https://developer.hashicorp.com/terraform/language/block/import (`to`, `id`, `identity`, `for_each`) | Migration | 4 |
| 65 | Terraform Docs | *Import existing resources into Terraform state*, https://developer.hashicorp.com/terraform/language/import/single-resource | Migration | 4 |
| 66 | Terraform Docs | *Import - Generating Configuration*, https://developer.hashicorp.com/terraform/language/import/generating-configuration (`-generate-config-out`, experimental) | Migration | 4 |
| 67 | Terraform Docs | *variable block reference*, https://developer.hashicorp.com/terraform/language/block/variable (`deprecated`, `validation`) | Module interface | 2 |
| 68 | Terraform Docs | *Terraform changelog v1.11*, https://github.com/hashicorp/terraform/blob/v1.11/CHANGELOG.md ("S3 native state locking is now generally available") | Version of S3 native locking | 1 |
| 69 | Terraform Docs | *Terraform changelog v1.12*, https://github.com/hashicorp/terraform/blob/v1.12/CHANGELOG.md (`identity` in `import` blocks) | Migration | 4 |
| 70 | HashiCorp | Terraform v1.17.1 download and SHA256 checksum file, https://releases.hashicorp.com/terraform/1.17.1/ (checksum checked with `shasum -a 256 -c`; signature not checked) | Running validation and tests | Validation of all tasks |
| 71 | Terraform Docs | *jsondecode* function, https://developer.hashicorp.com/terraform/language/functions/jsondecode | Policy checks | 3 |
| 72 | Terraform Docs | *can* function, https://developer.hashicorp.com/terraform/language/functions/can | Policy checks | 3 |
| 73 | Terraform Docs | *flatten* function, https://developer.hashicorp.com/terraform/language/functions/flatten | Policy checks | 3 |
| 74 | Terraform Docs | *alltrue* function, https://developer.hashicorp.com/terraform/language/functions/alltrue | Policy checks | 3 |
| 75 | Terraform Docs | *file* function, https://developer.hashicorp.com/terraform/language/functions/file | Policy checks | 3 |
| 76 | Terraform Docs | *output block reference*, https://developer.hashicorp.com/terraform/language/block/output (`precondition` in an output) | Exception register | 3 |
| 77 | Terraform Docs | *timecmp* function, https://developer.hashicorp.com/terraform/language/functions/timecmp (RFC 3339, returns -1, 0 or 1) | Exception register | 3 |
| 78 | Terraform Docs | *timeadd* function, https://developer.hashicorp.com/terraform/language/functions/timeadd (duration units such as `h`) | Exception register | 3 |
| 79 | Terraform Docs | *plantimestamp* function, https://developer.hashicorp.com/terraform/language/functions/plantimestamp (Terraform 1.5 or later) | Exception register | 3 |
| 80 | Terraform Docs | *coalesce* function, https://developer.hashicorp.com/terraform/language/functions/coalesce | Exception register | 3 |
| 81 | Terraform Docs | *try* function, https://developer.hashicorp.com/terraform/language/functions/try | Exception register | 3 |
| 82 | AWS Docs | *Service reference information*, https://docs.aws.amazon.com/service-authorization/latest/reference/service-reference.html (JSON files for actions and resource types; read for `cloudtrail` and `s3`) | SCP action names and bucket ARN format | 3 |
| 83 | Terraform Docs | *JSON Output Format*, https://developer.hashicorp.com/terraform/internals/json-format (`resource_changes`, `change.actions`) | Replace detection from a saved plan | 5 |
