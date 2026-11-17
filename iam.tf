# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

## +-------
## | IAM - CodePipeline execution role
## +---------------------------------

resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-pipeline-role"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.project_name}-pipeline"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketAcl"
        ]
        Resource = [
          "${aws_s3_bucket.artifacts.arn}",
          "${aws_s3_bucket.artifacts.arn}/*",
          "${aws_s3_bucket.tfstate.arn}/*",
          "${aws_s3_bucket.tfstate.arn}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = [
          aws_codebuild_project.validation.arn,
          aws_codebuild_project.apply.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.pipeline_key.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish",
        ]
        Resource = aws_sns_topic.approval_notification.arn
      },
      {
        Effect = "Allow"
        Action = var.provider_type != "CodeCommit" ? [
          "codeconnections:UseConnection",
          "codestar-connections:UseConnection"
        ] : [
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:UploadArchive",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:CancelUploadArchive"
        ]
        Resource = var.provider_type != "CodeCommit" ? aws_codestarconnections_connection.connection[0].arn : aws_codecommit_repository.repository[0].arn
      }
    ]
  })
}

## +-------
## | IAM - CodeBuild execution roles for plan & apply steps
## +---------------------------------

resource "aws_iam_role" "codebuild_role_plan" {
  name = "${var.project_name}-codebuild-role-plan"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_policy_plan" {
  name = "${var.project_name}-codebuild-policy-plan"
  role = aws_iam_role.codebuild_role_plan.id


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = local.validation_log_group_arns
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.artifacts.arn}/*",
          "${aws_s3_bucket.tfstate.arn}/*",
          "${aws_s3_bucket.tfstate.arn}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.pipeline_key.arn
      },
      {
        Effect = "Allow"
        Action = [
          "Organizations:DescribePolicy",
          "Organizations:ListTargetsForPolicy"
        ]
        Resource = local.org_policy_arns
      },
      {
        # Policy tags are read by Terraform, account tags by the policy processors (tag-based targets)
        Effect = "Allow"
        Action = [
          "Organizations:ListTagsForResource"
        ]
        Resource = concat(local.org_policy_arns, local.org_account_arns)
      }
    ], local.bedrock_statements)
  })
}

# Actions without resource-level permissions are kept in a separate policy, so the
# resource-scoped policy above has no statement with Resource "*".
resource "aws_iam_role_policy" "codebuild_policy_plan_unscoped" {
  # checkov:skip=CKV_AWS_355:access-analyzer:CheckNoNewAccess, access-analyzer:ValidatePolicy and organizations:ListAccounts do not support resource-level permissions, so Resource must be "*"
  name = "${var.project_name}-codebuild-policy-plan-unscoped"
  role = aws_iam_role.codebuild_role_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "access-analyzer:CheckNoNewAccess",
          "access-analyzer:ValidatePolicy",
          "Organizations:ListAccounts"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "codebuild_role_apply" {
  name = "${var.project_name}-codebuild-role-apply"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_policy_apply" {
  name = "${var.project_name}-codebuild-policy-apply"
  role = aws_iam_role.codebuild_role_apply.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = local.apply_log_group_arns
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.artifacts.arn}/*",
          "${aws_s3_bucket.tfstate.arn}/*",
          "${aws_s3_bucket.tfstate.arn}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.pipeline_key.arn
      },
      {
        Effect = "Allow"
        Action = [
          "Organizations:CreatePolicy",
          "Organizations:DescribePolicy",
          "Organizations:UpdatePolicy",
          "Organizations:DeletePolicy",
          "Organizations:ListTagsForResource",
          "Organizations:ListTargetsForPolicy"
        ]
        Resource = local.org_policy_arns
      },
      {
        # Attach and detach are authorized against both the policy and the target (root, OU or account)
        Effect = "Allow"
        Action = [
          "Organizations:AttachPolicy",
          "Organizations:DetachPolicy"
        ]
        Resource = concat(local.org_policy_arns, local.org_target_arns)
      }
    ]
  })
}