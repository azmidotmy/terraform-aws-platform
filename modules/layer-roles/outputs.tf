output "plan_role_arn" {
  description = "ARN of the plan role (read only, lock object write)."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "ARN of the apply role (own layer only, permissions boundary attached)."
  value       = aws_iam_role.apply.arn
}
