# main.tf

# ECS 클러스터 정의
resource "aws_ecs_cluster" "prowler_cluster" {
  name = "prowler-cluster"
}

# Prowler Task Definition 정의
resource "aws_ecs_task_definition" "prowler_task" {
  family                   = "prowler-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu    = "4096"  # 4 vCPU
  memory = "16384" # 16GB RAM

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name       = "prowler"
      image      = "yyyy7246/prowler-custom:latest5"
      essential  = true
      entryPoint = ["/bin/sh", "-c"]
      command    = ["date -Iseconds > /prowler/start_time.txt; aws s3 cp s3://${var.s3_bucket_name}/compliance/${var.compliance_file} /home/prowler/.local/lib/python3.12/site-packages/prowler/compliance/aws/${var.compliance_type}.json; prowler aws --compliance ${var.compliance_type} --checks-folder /prowler/custom_checks --log-level DEBUG; echo 'Setting permissions...' && chmod -R 755 /prowler/output/*; timestamp=$(date +'%Y%m%d%H%M%S'); echo 'Compressing results...' && tar -czvf /prowler/output/prowler-results-$timestamp.tar.gz -C /prowler/output .; echo 'Starting S3 upload...' && aws s3 cp /prowler/output/prowler-results-$timestamp.tar.gz s3://${var.s3_bucket_name}/ && echo 'S3 upload completed successfully.' || echo 'S3 upload failed.'; python3 /home/prowler/send_to_slack.py; aws ecs update-service --cluster prowler-cluster --service prowler-service --desired-count 0"]

      environment = [
        {
          name  = "S3_BUCKET_NAME"
          value = var.s3_bucket_name
        },
        {
          name  = "SLACK_WEBHOOK_URL"
          value = var.slack_webhook_url
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/prowler"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  depends_on = [aws_iam_role.ecs_task_execution_role]
}

# 단발성 태스크 실행을 위한 ECS 서비스
resource "aws_ecs_service" "prowler_service" {
  name            = "prowler-service"
  cluster         = aws_ecs_cluster.prowler_cluster.id
  task_definition = aws_ecs_task_definition.prowler_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.subnet_id]
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws ecs update-service --cluster ${self.cluster} --service ${self.name} --desired-count 0"
  }

  depends_on = [
    aws_iam_role.ecs_task_execution_role,
    aws_ecs_task_definition.prowler_task,
    aws_ecs_cluster.prowler_cluster
  ]
}

# CloudWatch 이벤트 규칙 - 매일 특정 시간에 실행
resource "aws_cloudwatch_event_rule" "daily_prowler" {
  name                = "daily-prowler-check"
  description         = "Triggers Prowler check daily"
  schedule_expression = "cron(0 0 * * ? *)"  # UTC 기준 매일 자정
}

# CloudWatch 이벤트 타겟 설정
resource "aws_cloudwatch_event_target" "ecs_prowler" {
  rule      = aws_cloudwatch_event_rule.daily_prowler.name
  target_id = "RunDailyProwlerCheck"
  arn       = aws_ecs_cluster.prowler_cluster.arn
  role_arn  = aws_iam_role.ecs_task_execution_role.arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.prowler_task.arn
    launch_type         = "FARGATE"

    network_configuration {
      subnets          = [var.subnet_id]
      security_groups  = [var.security_group_id]
      assign_public_ip = true
    }
  }

  depends_on = [
    aws_ecs_cluster.prowler_cluster,
    aws_ecs_task_definition.prowler_task
  ]
}
