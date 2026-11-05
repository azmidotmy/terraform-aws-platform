# layer-roles

**Owner:** central platform. **Current version:** 0.1.0 (unreleased sample). **Layer:** `baseline`.

Creates the two IAM roles one pipeline needs for one layer in one virtual account (`docs/01`, section 1.3):

| Role | Can | Cannot |
|---|---|---|
| `<virtual-account>-<layer>-plan` | Read the layer's state. Get, put and delete the `*.tflock` lock object | Write state. Change resources |
| `<virtual-account>-<layer>-apply` | Get and put the layer's state. Use the lock object. Use `apply_policy_json` for the layer's resources. Has a permissions boundary | Delete the state object. Reach another layer's state keys |

The state permissions follow *Backend Type: s3*, section "Permissions Required" (https://developer.hashicorp.com/terraform/language/backend/s3).

Each role trusts `codebuild.amazonaws.com` only when `aws:SourceArn` is its own CodeBuild project.

## Usage

```hcl
module "roles" {
  source = "../../../modules/layer-roles"   # pin a Git tag when shared: git::<url>?ref=v1.0.0

  virtual_account = "prod"
  layer           = "workload"
  codebuild_project_arns = {
    plan  = "arn:aws:codebuild:ap-southeast-5:111122223333:project/prod-workload-plan"
    apply = "arn:aws:codebuild:ap-southeast-5:111122223333:project/prod-workload-apply"
  }
  state_bucket_arn         = module.state_bucket.bucket_arn
  kms_key_arn              = "arn:aws:kms:ap-southeast-5:111122223333:key/11111111-2222-3333-4444-555555555555"
  permissions_boundary_arn = "arn:aws:iam::111122223333:policy/boundary-workload-apply"
  apply_policy_json        = file("${path.module}/apply-policy.json")
}
```

It uses the `bucket_arn` output of [`secure-state-bucket`](../secure-state-bucket/). The stack joins the two modules. The modules do not call each other (`docs/02`, section 2.2).

## Inputs and outputs

Generated from the `description` fields in `variables.tf` and `outputs.tf`.

## Tests

```
terraform init
terraform test
```

Executed on Terraform v1.17.1: 9 passed, 0 failed (mocked AWS provider; no real resources). Checked by hand: when the plan role is changed to write the state object, `plan_role_writes_only_the_lock_object` fails. When the apply role is allowed to delete the state object, `apply_role_cannot_delete_the_state_object` fails.

## Known limits

- **Unverified:** whether `terraform plan` needs `s3:PutObject` on the state object itself. The docs list Get and Put on the state key without saying which command needs which.
- The module cannot check that `plan_policy_json` is read-only, or that `apply_policy_json` stays inside the layer. Review and the permissions boundary cover that.
- The boundary policy is an example (`policies/iam/boundary-workload-apply.json`).

## Upgrade notes

None yet. Interface changes follow `docs/02-module-product-model.md`, section 2.3.
