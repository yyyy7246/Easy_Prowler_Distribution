variable "aws_region" {
  description = "AWS region to deploy resources in"
  default     = "us-west-1"
}

variable "subnet_id" {
  description = "Subnet ID for ECS Fargate tasks"
  type        = string
}

variable "security_group_id" {
  description = "Security Group ID for ECS Fargate tasks"
  type        = string
}


variable "s3_bucket_name" {
  description = "S3 bucket to store Prowler reports"
  type        = string
}


variable "slack_webhook_url" {
  description = "Slack Webhook URL"
  type        = string
}

variable "compliance_type" {
  description = "The compliance type for Prowler scan (e.g., custom_ccpa_aws, custom_gdpr_aws, custom_k_pipa_aws)"
  type        = string
  default     = "custom_ccpa_aws" # 기본값을 설정합니다.
}

variable "compliance_file" {
  description = "Name of the compliance ruleset JSON file"
  type        = string
}