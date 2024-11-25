#!/bin/bash

# ECS 서비스의 desired-count를 0으로 설정하여 작업 중지
echo "ECS 서비스의 desired-count를 0으로 설정합니다..."
aws ecs update-service --cluster prowler-cluster --service prowler-service --desired-count 0 || { echo "ECS 서비스 업데이트에 실패했습니다."; }

# Terraform 초기화
echo "Terraform 초기화를 진행합니다..."
terraform init -input=false || { echo "Terraform 초기화에 실패했습니다."; exit 1; }

# 리소스 삭제
echo "Terraform 리소스를 삭제합니다..."
terraform destroy -auto-approve || { echo "Terraform 리소스 삭제에 실패했습니다."; exit 1; }

echo "Terraform 리소스 삭제가 완료되었습니다."

