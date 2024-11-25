aws_region         = "INPUT AWS REGION" # ex) us-west-1

subnet_id          = "INPUT SUBNET ID" # ex) subnet-***...

security_group_id  = "INPUT SG ID" # ex) sg-***...

s3_bucket_name     = "INPUT S3 BUCKET NAME" # You must enter a unique name.

slack_webhook_url  = "INPUT SLACK WEBHOOK URL" # ex) https://hooks.slack.com/services/*****/*****/*****

compliance_type = "custom_ccpa_aws" # ex) "custom_ccpa_aws" 
# compliance type option : 1. custom_ccpa_aws, 2.custom_gdpr_aws, 3. custom_k_pipa_aws


compliance_file    = ""
# ex) compliance_rules_CCPA_2024-11-23.json
# You can download custom rule sets at https://yyyy7246.github.io/CustomRuleGenerator/.
