# Run from the policies/checks folder:  terraform init && terraform test
# Syntax: Terraform Docs, "Tests" (https://developer.hashicorp.com/terraform/language/tests).
# The file() paths are relative to the folder where terraform test runs.

run "scp_follows_the_standards" {
  command = plan
  variables {
    policy = { kind = "scp", json = file("../scp/protect-state-and-audit.json") }
  }
  assert {
    condition     = output.statement_count == 2
    error_message = "The SCP example must have two statements."
  }
}

run "approver_policy_follows_the_standards" {
  command = plan
  variables {
    policy = { kind = "iam", json = file("../iam/approver-prod-workload.json") }
  }
  assert {
    condition     = output.statement_count == 3
    error_message = "The approver policy must have three statements."
  }
}

run "boundary_follows_the_standards" {
  command = plan
  variables {
    policy = { kind = "iam", json = file("../iam/boundary-workload-apply.json") }
  }
  assert {
    condition     = output.statement_count == 2
    error_message = "The boundary must have two statements."
  }
}

run "bucket_policy_follows_the_standards" {
  command = plan
  variables {
    policy = { kind = "bucket", json = file("../bucket/state-bucket-tls-only.json") }
  }
  assert {
    condition     = output.statement_count == 1
    error_message = "The bucket policy must have one statement."
  }
}

run "rejects_allow_all_actions" {
  command = plan
  variables {
    policy = {
      kind = "iam"
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"Bad\",\"Effect\":\"Allow\",\"Action\":\"*\",\"Resource\":\"*\"}]}"
    }
  }
  expect_failures = [var.policy]
}

run "rejects_statement_without_sid" {
  command = plan
  variables {
    policy = {
      kind = "iam"
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Deny\",\"Action\":\"s3:*\",\"Resource\":\"*\"}]}"
    }
  }
  expect_failures = [var.policy]
}

run "rejects_scp_with_allow" {
  command = plan
  variables {
    policy = {
      kind = "scp"
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"AllowS3\",\"Effect\":\"Allow\",\"Action\":\"s3:GetObject\",\"Resource\":\"*\"}]}"
    }
  }
  expect_failures = [var.policy]
}

run "rejects_text_that_is_not_json" {
  command = plan
  variables {
    policy = { kind = "iam", json = "not json" }
  }
  expect_failures = [var.policy]
}
