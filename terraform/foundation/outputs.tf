# VPC and Network
output "vpc_id" {
    description = "VPC ID"
    value = aws_vpc.main.id
}

output "public_subnet_ids" {
    description = "Public subnet IDs"
    value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
    description = "Private subnet IDs"
    value = aws_subnet.private[*].id
}

# Security Groups
output "alb_security_group_id" {
    description = "ALB security group ID"
    value = aws_security_group.alb.id
}

output "web_security_group_id" {
    description = "Web security group ID"
    value = aws_security_group.web.id
}

output "daemon_security_group_id" {
    description = "Daemon security group ID"
    value = aws_security_group.daemon.id
}

output "user_code_security_group_id" {
    description = "User code security group ID"
    value = aws_security_group.user_code.id
}

# RDS
output "rds_endpoint" {
    description = "RDS endpoint"
    value = aws_db_instance.main.address
}

# ECR
output "dagster_ecr_repository_url" {
    description = "Dagster ECR repository URL"
    value = aws_ecr_repository.dagster.repository_url
}

output "user_code_ecr_repository_url" {
    description = "User code ECR repository URL"
    value = aws_ecr_repository.user_code.repository_url
}

# IAM
output "task_role_arn" {
    description = "Task role ARN"
    value = aws_iam_role.task.arn
}

output "execution_role_arn" {
    description = "Execution role ARN"
    value = aws_iam_role.execution.arn
}

# Secrets Manager
output "dagster_postgres_secret_arn" {
    description = "Dagster PostgreSQL secret ARN"
    value = aws_secretsmanager_secret.dagster_postgres.arn
}

output "dbt_snowflake_secret_arn" {
    description = "DBT Snowflake secret ARN"
    value = aws_secretsmanager_secret.dbt_env_secret_snowflake.arn
}
