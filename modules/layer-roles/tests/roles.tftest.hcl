# Syntax: Terraform Docs, "Tests" (https://developer.hashicorp.com/terraform/language/tests)
# and "Tests - Provider Mocking" (https://developer.hashicorp.com/terraform/language/tests/mocking)
mock_provider "aws" {}

variables {
  virtual_account = "prod"
  layer           = "workload"
  codebuild_project_arns = {
    plan  = "arn:aws:codebuild:ap-southeast-5:111122223333:project/prod-workload-plan"
    apply = "arn:aws:codebuild:ap-southeast-5:111122223333:project/prod-workload-apply"
  }
  state_bucket_arn         = "arn:aws:s3:::example-prod-tfstate-111122223333-ap-southeast-5"
  kms_key_arn              = "arn:aws:kms:ap-southeast-5:111122223333:key/11111111-2222-3333-4444-555555555555"
  permissions_boundary_arn = "arn:aws:iam::111122223333:policy/boundary-workload-apply"
  apply_policy_json        = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
}

run "role_names_follow_the_matrix" {
  command = plan

  assert {
    condition     = aws_iam_role.plan.name == "prod-workload-plan" && aws_iam_role.apply.name == "prod-workload-apply"
    error_message = "Role names must be <virtual-account>-<layer>-plan and -apply (docs/01, 1.3 matrix)."
  }
}

run "each_role_trusts_only_its_own_project" {
  command = plan

  assert {
    condition = (
      jsondecode(aws_iam_role.plan.assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceArn"] == var.codebuild_project_arns.plan &&
      jsondecode(aws_iam_role.apply.assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceArn"] == var.codebuild_project_arns.apply
    )
    error_message = "Each trust policy must be bound to one CodeBuild project with aws:SourceArn."
  }
}

run "only_apply_has_a_permissions_boundary" {
  command = plan

  assert {
    condition     = aws_iam_role.apply.permissions_boundary == var.permissions_boundary_arn && aws_iam_role.plan.permissions_boundary == null
    error_message = "The apply role must carry the permissions boundary."
  }
}

run "plan_role_writes_only_the_lock_object" {
  command = plan

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.plan_state.policy).Statement :
      s.Resource == "${var.state_bucket_arn}/workload/*.tflock"
      if contains(flatten([s.Action]), "s3:PutObject") || contains(flatten([s.Action]), "s3:DeleteObject")
    ])
    error_message = "The plan role may write only the *.tflock object."
  }
}

run "state_access_is_limited_to_the_layer_prefix" {
  command = plan

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.apply_state.policy).Statement :
      endswith(s.Resource, "/workload/*") || endswith(s.Resource, "/workload/*.tflock") || s.Resource == var.state_bucket_arn || s.Resource == var.kms_key_arn
    ])
    error_message = "State object permissions must be limited to <layer>/*."
  }
}

run "apply_role_cannot_delete_the_state_object" {
  command = plan

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.apply_state.policy).Statement :
      endswith(s.Resource, ".tflock")
      if contains(flatten([s.Action]), "s3:DeleteObject")
    ])
    error_message = "s3:DeleteObject is allowed only on the lock object (the docs say it is not needed on the state file)."
  }
}

run "rejects_same_project_for_plan_and_apply" {
  command = plan

  variables {
    codebuild_project_arns = {
      plan  = "arn:aws:codebuild:ap-southeast-5:111122223333:project/same"
      apply = "arn:aws:codebuild:ap-southeast-5:111122223333:project/same"
    }
  }

  expect_failures = [var.codebuild_project_arns]
}

run "rejects_unknown_layer" {
  command = plan

  variables {
    layer = "everything"
  }

  expect_failures = [var.layer]
}

run "rejects_invalid_apply_policy" {
  command = plan

  variables {
    apply_policy_json = "not json"
  }

  expect_failures = [var.apply_policy_json]
}
