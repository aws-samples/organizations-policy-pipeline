# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

data "aws_caller_identity" "current" {}

data "aws_organizations_organization" "org" {}

data "aws_region" "current" {}