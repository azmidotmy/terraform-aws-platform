# Syntax: Terraform Docs, "Tests" (https://developer.hashicorp.com/terraform/language/tests)
# and "Tests - Provider Mocking" (https://developer.hashicorp.com/terraform/language/tests/mocking).
# mock_provider arrived in Terraform 1.7.

mock_provider "aws" {}

variables {
  bucket_name = "example-nonprod-tfstate-111122223333-ap-southeast-5"
  kms_key_arn = "arn:aws:kms:ap-southeast-5:111122223333:key/11111111-2222-3333-4444-555555555555"
}

run "versioning_is_enabled" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be Enabled on the state bucket."
  }
}

run "encryption_uses_kms" {
  command = plan

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    error_message = "State must be encrypted with SSE-KMS."
  }
}

run "public_access_is_blocked" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.this.block_public_acls,
      aws_s3_bucket_public_access_block.this.block_public_policy,
      aws_s3_bucket_public_access_block.this.ignore_public_acls,
      aws_s3_bucket_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "All four public access block settings must be true."
  }
}

run "rejects_invalid_kms_arn" {
  command = plan

  variables {
    kms_key_arn = "not-an-arn"
  }

  expect_failures = [
    var.kms_key_arn,
  ]
}
