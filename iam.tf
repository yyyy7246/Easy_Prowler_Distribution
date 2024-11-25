# iam.tf

# AWS 계정 ID를 참조하기 위해 사용
data "aws_caller_identity" "current" {}

# ECS Task Execution Role 정의
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "prowler-task-execution-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : ["ecs-tasks.amazonaws.com", "ec2.amazonaws.com"]
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Prowler 추가 권한 정책 정의
resource "aws_iam_policy" "prowler_additional_policy" {
  name = "ProwlerAdditionalPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "access-analyzer:List*",
          "account:Get*",
          "acm:Describe*",
          "acm:List*",
          "apigateway:GET",
          "appstream:Describe*",
          "appstream:List*",
          "backup:List*",
          "cloudtrail:GetEventSelectors",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:DescribeTrails",
          "cloudtrail:LookupEvents",
          "cloudtrail:List*",
          "cloudformation:Describe*",
          "cloudformation:List*",
          "cloudfront:List*",
          "cloudhsm:Describe*",
          "cloudhsm:List*",
          "cloudwatch:Describe*",
          "cloudwatch:List*",
          "codecommit:List*",
          "codedeploy:List*",
          "codepipeline:List*",
          "cognito-identity:List*",
          "cognito-idp:List*",
          "config:Get*",
          "config:List*",
          "dynamodb:List*",
          "ds:List*",
          "ec2:Describe*",
          "ec2:Get*",
          "ecr:Describe*",
          "ecr:List*",
          "ecs:Describe*",
          "ecs:List*",
          "eks:Describe*",
          "eks:List*",
          "elasticache:Describe*",
          "elasticache:List*",
          "elasticbeanstalk:Describe*",
          "elasticbeanstalk:List*",
          "elasticloadbalancing:Describe*",
          "elasticmapreduce:List*",
          "es:List*",
          "guardduty:List*",
          "iam:Generate*",
          "iam:Get*",
          "iam:List*",
          "kms:Describe*",
          "kms:Get*",
          "kms:List*",
          "lambda:List*",
          "logs:Describe*",
          "logs:List*",
          "organizations:Describe*",
          "organizations:List*",
          "rds:Describe*",
          "rds:List*",
          "redshift:Describe*",
          "route53:List*",
          "s3:Get*",
          "s3:List*",
          "sagemaker:List*",
          "secretsmanager:List*",
          "securityhub:List*",
          "ses:List*",
          "shield:List*",
          "sns:List*",
          "sqs:List*",
          "ssm:Describe*",
          "ssm:Get*",
          "tag:Get*",
          "waf:List*",
          "waf-regional:List*",
          "wafv2:List*",
          "workspaces:Describe*",
          "access-analyzer:GetAnalyzer",
          "access-analyzer:GetFinding",
          "access-analyzer:GetGeneratedPolicy",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "directconnect:DescribeDirectConnectGateways",
          "directconnect:DescribeDirectConnectGatewayAssociations",
          "ec2:GetEbsEncryptionByDefault",
          "ecr:DescribeImageScanFindings",
          "eks:DescribeCluster",
          "macie2:GetMacieSession",
          "organizations:DescribeOrganization",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "systems-manager:GetDocument",
          "config:GetResourceConfigHistory",
          "config:SelectResourceConfig",
          "config:DescribeConfigurationRecorders",
          "config:DescribeConfigurationRecorderStatus"
        ]
        Resource = "*"
      }
    ]
  })
}


resource "aws_s3_bucket" "prowler_bucket" {
  bucket        = var.s3_bucket_name
  force_destroy = true
}

resource "aws_s3_object" "compliance_file" {
  bucket = aws_s3_bucket.prowler_bucket.id
  key    = "compliance/${var.compliance_file}"
  source = "${path.module}/${var.compliance_file}"
  etag   = filemd5("${path.module}/${var.compliance_file}")
}

# S3, CloudWatch Logs 및 ECS UpdateService에 접근 가능한 정책 정의
resource "aws_iam_policy" "prowler_s3_access_and_logs_policy" {
  name = "ProwlerS3AndLogsAccessPolicy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:ListBucket",
          "s3:GetBucketCORS", 
          "s3:PutBucketCORS"
        ],
        "Resource" : [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/prowler:*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ecs:UpdateService"
        ],
        "Resource" : [
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/prowler-cluster/prowler-service"
        ]
      }
    ]
  })
}

# SecurityAudit 정책 연결
resource "aws_iam_role_policy_attachment" "security_audit_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"

  depends_on = [aws_iam_role.ecs_task_execution_role]
}

# ViewOnlyAccess 정책 연결
resource "aws_iam_role_policy_attachment" "view_only_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"

  depends_on = [aws_iam_role.ecs_task_execution_role]
}

# Prowler 추가 정책 연결
resource "aws_iam_role_policy_attachment" "prowler_additional_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.prowler_additional_policy.arn

  depends_on = [aws_iam_role.ecs_task_execution_role]
}

# S3 및 로그 정책 연결
resource "aws_iam_role_policy_attachment" "prowler_execution_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.prowler_s3_access_and_logs_policy.arn

  depends_on = [aws_iam_role.ecs_task_execution_role]
}

# ECS 작업 실행을 위한 기본 정책 연결
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"

  depends_on = [aws_iam_role.ecs_task_execution_role]
}

# CloudWatch 로그 그룹 생성
resource "aws_cloudwatch_log_group" "prowler_log_group" {
  name              = "/ecs/prowler"
  retention_in_days = 7

  depends_on = [aws_iam_role.ecs_task_execution_role]
}

