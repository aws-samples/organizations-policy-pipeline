resource "aws_codecommit_repository" "repository" {
  count = var.provider_type == "CodeCommit" ? 1 : 0
  repository_name = split("/", var.full_repository_name)[1]
  description     = "AWS Organization Policy management repository"
  kms_key_id      = aws_kms_key.pipeline_key.arn
  default_branch = var.branch_name
  tags = var.tags
}

