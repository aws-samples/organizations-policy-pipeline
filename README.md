# Organization Policy Management Pipeline
## Overview
Authorization policies in AWS Organizations enable you to centrally configure and manage access for principals and resources in your member accounts. How those policies affect the organizational units (OUs) and accounts that you apply them to depends on the type of authorization policy that you apply. Service Control Policies (SCPs) are principal-centric controls. SCPs create a permissions guardrail, or set limits, on the maximum permissions available to principals in your member accounts. Resource Control Policies (RCPs) are resource-centric controls. RCPs create a permissions guardrail, or set limits, on the maximum permissions available for resources in your member accounts.

This pattern helps you to manage SCP and RCP as code abstracting the burden of having to build and maintain multiple policies with different guardrails using CloudFormation or Terraform. With this pattern, you can achieve the following:
- Create, delete, update SCP/RCPs using a “manifest” JSON file (scp-management.json and rcp-management.json)
- Work with guardrails, not policies. You define your preventive guardrails and its Targets (see below) and the pipeline will do the rest: it will merge and optimize your guardrails in a single policy and apply in the Target as described in the manifest file
- Apply SCP/RCP policies in your targets. A target in the pipeline could be:
    - An AWS account
    - An Organization Unit (OU)-
    - An Environment (a group of OU and/or accounts defined in the environments.json file)
    - A tag: a group of account that shares the same key:value tag
- A manual approval is required in the pipeline. This pattern uses Amazon Bedrock to read an summarize all pipeline logs in an executive summary to send to approvers so they don’t have to dig into the logs to understand and approve proposed changes
To manage SCP and RCP as code, this solution deploys a continuous integration and continuous delivery (CI/CD) pipeline that uses AWS CodeBuild and AWS CodePipeline.

The code in this repository helps you set up the following target architecture.

![Architecture](images/org-mgmt-architecture.png)


For prerequisites and instructions for using this AWS Prescriptive Guidance pattern, see Manage AWS Organizations Service Control Policies (SCP) and Resource Control Policies (RCP) as code by using AWS CodePipeline powered by Amazon Bedrock.

