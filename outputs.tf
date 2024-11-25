output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value       = aws_ecs_cluster.prowler_cluster.name
}

output "s3_bucket_name" {
  description = "S3 Bucket for Prowler reports"
  value       = var.s3_bucket_name
}

