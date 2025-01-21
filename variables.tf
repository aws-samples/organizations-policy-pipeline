# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "project_name" {
  description = "Project name"
  default     = "org-policy-mgmt"
}

variable "provider_type" {
  description = "The name of the external provider where your third-party code repository is configured. Valid values are Bitbucket, GitHub, GitHubEnterpriseServer, GitLab or GitLabSelfManaged"
  default     = "Provider"
}

variable "full_repository_name" {
  description = "The name of the code repository where Organization Policies will be managed. Pattern would be 'org/repo_name'"
  default     = "org/repo"
}

variable "branch_name" {
  description = "The name of the Git branch that will be used for Policies deployment"
  default     = "main"
}

variable "terraform_version" {
  description = "Terraform version to be used in the pipeline"
  type = string
  default     = "1.9.8"
}

variable "enable_bedrock" {
  description = "Enable Amazon Bedrock to summarize pipeline logs for manual approval stage"
  type = bool
  default     = true
}

variable "tags" {
  description = "Tags for resources"
  default = {
    environment = "prd"
    terraform   = "true"
  }
}