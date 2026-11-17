# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
## +-------
## | Terraform Locals - Auxiliary information
## +---------------------------------
locals {
  terraform_version = var.terraform_version

  # Primary key fingerprint of the HashiCorp release signing key (security@hashicorp.com).
  # Used to verify the Terraform binary downloaded in the CodeBuild projects.
  hashicorp_pgp_fingerprint = "C874011F0AB405110D02105534365D9472D7468F"

  # AWS Organizations ARNs used to scope the CodeBuild roles to SCPs and RCPs of this organization.
  # Organizations resources always carry the management account ID, also when the pipeline is
  # deployed in a delegated administrator account.
  org_arn_prefix = "arn:aws:organizations::${data.aws_organizations_organization.org.master_account_id}"
  org_id         = data.aws_organizations_organization.org.id
  org_policy_arns = [
    "${local.org_arn_prefix}:policy/${local.org_id}/service_control_policy/*",
    "${local.org_arn_prefix}:policy/${local.org_id}/resource_control_policy/*"
  ]
  org_account_arns = ["${local.org_arn_prefix}:account/${local.org_id}/*"]
  org_target_arns = concat([
    "${local.org_arn_prefix}:root/${local.org_id}/*",
    "${local.org_arn_prefix}:ou/${local.org_id}/*"
  ], local.org_account_arns)

  # CloudWatch Logs groups configured in the CodeBuild projects (logs_config)
  logs_arn_prefix = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group"
  validation_log_group_arns = [
    "${local.logs_arn_prefix}:${var.project_name}-validation",
    "${local.logs_arn_prefix}:${var.project_name}-validation:*"
  ]
  apply_log_group_arns = [
    "${local.logs_arn_prefix}:${var.project_name}-apply",
    "${local.logs_arn_prefix}:${var.project_name}-apply:*"
  ]

  # Amazon Bedrock ARNs derived from var.bedrock_model_id:
  # - "global.<model>": global cross-Region inference profile
  # - "us.<model>", "eu.<model>", ...: geographic cross-Region inference profile
  # - "<model>": foundation model invoked directly in the current Region
  bedrock_model_parts           = regex("^(?:(global|us|eu|apac|au|jp|in|ca)\\.)?(.+)$", var.bedrock_model_id)
  bedrock_profile_prefix        = local.bedrock_model_parts[0]
  bedrock_model_name            = local.bedrock_model_parts[1]
  bedrock_actions               = ["Bedrock:InvokeModel", "Bedrock:InvokeModelWithResponseStream"]
  bedrock_inference_profile_arn = "arn:aws:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_model_id}"
  bedrock_regional_model_arn    = "arn:aws:bedrock:${data.aws_region.current.region}::foundation-model/${local.bedrock_model_name}"

  # Foundation models behind an inference profile. Global profiles use the Region-less model ARN.
  # Geographic profiles route to Regions that AWS can extend over time, so the Region is a wildcard.
  bedrock_profile_model_arns = local.bedrock_profile_prefix == "global" ? [
    local.bedrock_regional_model_arn,
    "arn:aws:bedrock:::foundation-model/${local.bedrock_model_name}"
  ] : ["arn:aws:bedrock:*::foundation-model/${local.bedrock_model_name}"]

  bedrock_statements = concat(
    # Foundation model invoked directly
    local.bedrock_profile_prefix == null ? [
      {
        Effect   = "Allow"
        Action   = local.bedrock_actions
        Resource = local.bedrock_regional_model_arn
      }
    ] : [],
    # Inference profile
    local.bedrock_profile_prefix != null ? [
      {
        Effect   = "Allow"
        Action   = local.bedrock_actions
        Resource = local.bedrock_inference_profile_arn
      }
    ] : [],
    # Foundation models, reachable only through the inference profile
    local.bedrock_profile_prefix != null ? [
      {
        Effect   = "Allow"
        Action   = local.bedrock_actions
        Resource = local.bedrock_profile_model_arns
        Condition = {
          StringEquals = {
            "bedrock:InferenceProfileArn" = local.bedrock_inference_profile_arn
          }
        }
      }
    ] : []
  )

  # Languages available for the Amazon Bedrock summary. Each key is a valid value of
  # var.bedrock_summary_language, and its value is the language name written into the prompt.
  # To support a new language, add an entry here.
  bedrock_summary_languages = {
    "en"    = "English"
    "es"    = "Spanish"
    "pt-BR" = "Brazilian Portuguese"
  }
}
