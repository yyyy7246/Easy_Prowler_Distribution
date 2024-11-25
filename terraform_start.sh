#!/bin/bash

# Terraform 초기화
echo "Terraform 초기화를 진행합니다..."
terraform init

# 변수 정의
ROLE_NAME="prowler-task-execution-role"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_NAME1="ProwlerS3AndLogsAccessPolicy"
POLICY_NAME2="ProwlerAdditionalPolicy"
SECURITY_AUDIT_POLICY_ARN="arn:aws:iam::aws:policy/SecurityAudit"
VIEW_ONLY_POLICY_ARN="arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
ADDITIONAL_POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME2"
S3_LOGS_POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME1"
ECS_TASK_EXECUTION_POLICY_ARN="arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
BUCKET_NAME="terraformtestingprowler"
CLUSTER_NAME="prowler-cluster"
LOG_GROUP_NAME="/ecs/prowler"

# 리소스 확인 및 import를 위한 통합 함수
check_and_import_resource() {
    local resource_type=$1
    local resource_name=$2
    local terraform_resource=$3
    local check_command=$4
    local import_value=$5

    echo "Checking $resource_type '$resource_name'..."
    eval "$check_command" > /dev/null 2>&1
    local EXISTS=$?

    if [[ $EXISTS -eq 0 ]]; then
        echo "$resource_type '$resource_name'이 이미 존재합니다. 상태에 추가 중..."
        terraform import "$terraform_resource" "$import_value" || true
    else
        echo "$resource_type '$resource_name'이 존재하지 않으므로 Terraform에서 생성합니다."
    fi
}

# IAM 정책 확인 및 import 함수
check_and_import_policy() {
    local policy_name=$1
    local policy_arn=$2
    local terraform_resource_name=$3

    echo "Checking IAM Policy '$policy_name'..."
    aws iam get-policy --policy-arn "$policy_arn" > /dev/null 2>&1
    local POLICY_EXISTS=$?

    if [[ $POLICY_EXISTS -eq 0 ]]; then
        echo "IAM 정책 '$policy_name'이 이미 존재합니다. 상태에 추가 중..."
        # 정책의 현재 버전 확인
        local POLICY_VERSION=$(aws iam get-policy --policy-arn "$policy_arn" --query 'Policy.DefaultVersionId' --output text)
        echo "현재 정책 버전: $POLICY_VERSION"
        
        # 정책 import
        terraform import "$terraform_resource_name" "$policy_arn" || true
    else
        echo "IAM 정책 '$policy_name'이 존재하지 않으므로 Terraform에서 생성합니다."
    fi
}

# 정책 연결 확인 및 import 함수
check_and_import_policy_attachment() {
    local policy_name=$1
    local policy_arn=$2
    local terraform_resource_name=$3

    check_and_import_resource \
        "Policy attachment" \
        "$policy_name" \
        "aws_iam_role_policy_attachment.$terraform_resource_name" \
        "aws iam list-attached-role-policies --role-name \"$ROLE_NAME\" --query \"AttachedPolicies[?PolicyArn=='$policy_arn']\" --output text" \
        "$ROLE_NAME/$policy_arn"
}

# IAM 정책 확인 및 import
check_and_import_policy \
    "$POLICY_NAME1" \
    "$S3_LOGS_POLICY_ARN" \
    "aws_iam_policy.prowler_s3_access_and_logs_policy"

check_and_import_policy \
    "$POLICY_NAME2" \
    "$ADDITIONAL_POLICY_ARN" \
    "aws_iam_policy.prowler_additional_policy"

# 각 리소스 확인 및 import
check_and_import_resource \
    "IAM role" \
    "$ROLE_NAME" \
    "aws_iam_role.ecs_task_execution_role" \
    "aws iam get-role --role-name \"$ROLE_NAME\"" \
    "$ROLE_NAME"

check_and_import_resource \
    "S3 bucket" \
    "$BUCKET_NAME" \
    "aws_s3_bucket.prowler_bucket" \
    "aws s3api head-bucket --bucket \"$BUCKET_NAME\"" \
    "$BUCKET_NAME"

check_and_import_resource \
    "ECS cluster" \
    "$CLUSTER_NAME" \
    "aws_ecs_cluster.prowler_cluster" \
    "aws ecs describe-clusters --clusters \"$CLUSTER_NAME\" --query \"clusters[?status=='ACTIVE']\"" \
    "$CLUSTER_NAME"

check_and_import_resource \
    "CloudWatch Log Group" \
    "$LOG_GROUP_NAME" \
    "aws_cloudwatch_log_group.prowler_log_group" \
    "aws logs describe-log-groups --log-group-name-prefix \"$LOG_GROUP_NAME\" | grep \"$LOG_GROUP_NAME\"" \
    "$LOG_GROUP_NAME"

check_and_import_resource \
    "ECS Service Linked Role" \
    "AWSServiceRoleForECS" \
    "aws_iam_service_linked_role.ecs" \
    "aws iam get-role --role-name \"AWSServiceRoleForECS\"" \
    "ecs.amazonaws.com"

# 정책 연결 확인 및 import
check_and_import_policy_attachment "SecurityAudit" "$SECURITY_AUDIT_POLICY_ARN" "security_audit_policy"
check_and_import_policy_attachment "ViewOnlyAccess" "$VIEW_ONLY_POLICY_ARN" "view_only_policy"
check_and_import_policy_attachment "ProwlerAdditionalPolicy" "$ADDITIONAL_POLICY_ARN" "prowler_additional_policy_attachment"
check_and_import_policy_attachment "ProwlerS3AndLogsAccessPolicy" "$S3_LOGS_POLICY_ARN" "prowler_execution_policy_attachment"
check_and_import_policy_attachment "AmazonECSTaskExecutionRolePolicy" "$ECS_TASK_EXECUTION_POLICY_ARN" "ecs_task_execution_policy"

# Terraform 적용
terraform apply -auto-approve
