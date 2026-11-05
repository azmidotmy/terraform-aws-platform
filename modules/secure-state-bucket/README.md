# secure-state-bucket

**Owner:** central platform. **Current version:** 0.1.0 (unreleased sample). **Layer:** `baseline`.

Creates an Amazon S3 bucket for Terraform state with: versioning enabled, default server-side encryption with a customer-supplied KMS key (`aws:kms`, bucket keys on) and all four public access block settings on.

## Usage

```hcl
module "state_bucket" {
  source = "../../../modules/secure-state-bucket"   # pin a Git tag when shared: git::<url>?ref=v1.0.0

  bucket_name = "example-nonprod-tfstate-111122223333-ap-southeast-5"
  kms_key_arn = "arn:aws:kms:ap-southeast-5:111122223333:key/11111111-2222-3333-4444-555555555555"
  tags        = { VirtualAccount = "nonprod", Layer = "baseline", Owner = "central-platform" }
}
```

## Inputs and outputs

Generated from the `description` fields in `variables.tf` and `outputs.tf`.

## Tests

```
terraform init
terraform test
```

Executed on Terraform v1.17.1: 4 passed, 0 failed (mocked AWS provider; no real resources).

## Upgrade notes

None yet. Interface changes follow `docs/02-module-product-model.md`, section 2.3.
