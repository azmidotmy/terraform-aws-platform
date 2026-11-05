# Two roles per layer per virtual account (docs/01, section 1.3).
#   <virtual-account>-<layer>-plan   reads state; writes only the lock object
#   <virtual-account>-<layer>-apply  writes state and changes its own layer only, under a permissions boundary
#
# Trust policy form: AWS Docs, "Allow CodeBuild to interact with other AWS services"
#   Principal Service codebuild.amazonaws.com, Action sts:AssumeRole,
#   Condition StringEquals aws:SourceArn = CodeBuild project ARN.
# State permissions: Terraform Docs, "Backend Type: s3", section "Permissions Required"
#   (https://developer.hashicorp.com/terraform/language/backend/s3):
#     s3:ListBucket on the bucket;
#     s3:GetObject and s3:PutObject on the state key (s3:DeleteObject is not needed on the state file);
#     if use_lockfile is set, s3:GetObject, s3:PutObject and s3:DeleteObject on "<key>.tflock";
#     kms:Encrypt, kms:Decrypt and kms:GenerateDataKey on the KMS key (kms_key_id).
# Resource arguments: AWS provider docs for aws_iam_role and aws_iam_role_policy.

locals {
  prefix = "${var.virtual_account}-${var.layer}"

  # Every state key of this layer starts with "<layer>/" (docs/01, section 1.2).
  state_objects = "${var.state_bucket_arn}/${var.layer}/*"

  trust = { for k, arn in var.codebuild_project_arns : k => jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceArn" = arn } }
    }]
  }) }

  kms_statement = {
    Sid      = "StateKey"
    Effect   = "Allow"
    Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"]
    Resource = var.kms_key_arn
  }

  list_statement = {
    Sid      = "ListStateBucket"
    Effect   = "Allow"
    Action   = "s3:ListBucket"
    Resource = var.state_bucket_arn
  }
}

resource "aws_iam_role" "plan" {
  name               = "${local.prefix}-plan"
  assume_role_policy = local.trust["plan"]
  tags               = var.tags
}

# The plan role reads state. It writes only the lock object (*.tflock):
# the docs list Get, Put and Delete on the lock file when use_lockfile is set.
# UNVERIFIED: whether "terraform plan" needs Put on the state object itself.
# The docs list Get and Put on the state key without saying which command needs which.
resource "aws_iam_role_policy" "plan_state" {
  name = "state-read-and-lock"
  role = aws_iam_role.plan.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      local.list_statement,
      local.kms_statement,
      {
        Sid      = "ReadLayerState"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = local.state_objects
      },
      {
        Sid      = "LockObjectOnly"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${local.state_objects}.tflock"
      },
    ]
  })
}

resource "aws_iam_role_policy" "plan_extra" {
  count  = var.plan_policy_json == null ? 0 : 1
  name   = "layer-read"
  role   = aws_iam_role.plan.name
  policy = var.plan_policy_json
}

resource "aws_iam_role" "apply" {
  name                 = "${local.prefix}-apply"
  assume_role_policy   = local.trust["apply"]
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_role_policy" "apply_state" {
  name = "state-write"
  role = aws_iam_role.apply.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      local.list_statement,
      local.kms_statement,
      {
        Sid      = "WriteLayerState"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = local.state_objects
      },
      {
        Sid      = "LockObject"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${local.state_objects}.tflock"
      },
    ]
  })
}

resource "aws_iam_role_policy" "apply_layer" {
  name   = "layer-resources"
  role   = aws_iam_role.apply.name
  policy = var.apply_policy_json
}
