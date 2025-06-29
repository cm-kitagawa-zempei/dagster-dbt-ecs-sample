# Data sources to reference foundation outputs
data "terraform_remote_state" "foundation" {
    backend = "local"
    config = {
        path = "../foundation/terraform.tfstate"
    }
}

# Get current AWS region
data "aws_region" "current" {}

# ALB and Target Groups
resource "aws_lb" "main" {
    name = "${var.prefix}-dagster-ecs-alb"
    internal = false
    load_balancer_type = "application"
    security_groups = [data.terraform_remote_state.foundation.outputs.alb_security_group_id]
    subnets = data.terraform_remote_state.foundation.outputs.public_subnet_ids
}

resource "aws_lb_target_group" "web" {
    name = "${var.prefix}-dagster-ecs-alb-tg"
    port = 3000
    protocol = "HTTP"
    vpc_id = data.terraform_remote_state.foundation.outputs.vpc_id
    target_type = "ip"
    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200-399"
        interval = 30
        timeout = 5
        healthy_threshold = 2
        unhealthy_threshold = 2
    }
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.main.arn
    port = 80
    protocol = "HTTP"
    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.web.arn
    }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
    name = "${var.prefix}-dagster-ecs-cluster"
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "web" {
    name = "/ecs/${var.prefix}-dagster-ecs-web"
    retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "daemon" {
    name = "/ecs/${var.prefix}-dagster-ecs-daemon"
    retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "user_code" {
    name = "/ecs/${var.prefix}-dagster-ecs-user-code"
    retention_in_days = 30
}

# ECS Task Definitions
resource "aws_ecs_task_definition" "web" {
    family = "${var.prefix}-dagster-ecs-web"
    network_mode = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    cpu = 512
    memory = 1024
    execution_role_arn = data.terraform_remote_state.foundation.outputs.execution_role_arn
    task_role_arn = data.terraform_remote_state.foundation.outputs.task_role_arn
    container_definitions = jsonencode([
        {
            name = "${var.prefix}-dagster-ecs-web"
            image = "${data.terraform_remote_state.foundation.outputs.dagster_ecr_repository_url}:latest"
            entryPoint = ["dagster-webserver", "-h", "0.0.0.0", "-p", "3000"]
            portMappings = [
                {
                    containerPort = 3000
                    protocol = "tcp"
                }
            ]
            environment = [
                {
                    name = "DAGSTER_POSTGRES_HOST"
                    value = data.terraform_remote_state.foundation.outputs.rds_endpoint
                }
            ]
            secrets = [
                {
                    name = "DAGSTER_POSTGRES_DB"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dagster_postgres_secret_arn}:db_name::"
                },
                {
                    name = "DAGSTER_POSTGRES_USER"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dagster_postgres_secret_arn}:username::"
                },
                {
                    name = "DAGSTER_POSTGRES_PASSWORD"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dagster_postgres_secret_arn}:password::"
                }
            ]
            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    awslogs-group = "/ecs/${var.prefix}-dagster-ecs-web"
                    awslogs-region = data.aws_region.current.name
                    awslogs-stream-prefix = "ecs"
                }
            }
        }
    ])
}

resource "aws_ecs_service" "web" {
    name = "${var.prefix}-dagster-ecs-web"
    cluster = aws_ecs_cluster.main.id
    task_definition = aws_ecs_task_definition.web.arn
    desired_count = 1
    launch_type = "FARGATE"
    network_configuration {
        subnets = data.terraform_remote_state.foundation.outputs.private_subnet_ids
        security_groups = [data.terraform_remote_state.foundation.outputs.web_security_group_id]
        assign_public_ip = false
    }
    load_balancer {
        target_group_arn = aws_lb_target_group.web.arn
        container_name = "${var.prefix}-dagster-ecs-web"
        container_port = 3000
    }
    depends_on = [aws_lb_listener.http]
}

# Daemon Task Definition and Service
resource "aws_ecs_task_definition" "daemon" {
    family = "${var.prefix}-dagster-ecs-daemon"
    network_mode = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    cpu = 512
    memory = 1024
    execution_role_arn = data.terraform_remote_state.foundation.outputs.execution_role_arn
    task_role_arn = data.terraform_remote_state.foundation.outputs.task_role_arn
    container_definitions = jsonencode([
        {
            name = "${var.prefix}-dagster-ecs-daemon"
            image = "${data.terraform_remote_state.foundation.outputs.dagster_ecr_repository_url}:latest"
            entryPoint = ["dagster-daemon", "run"]
            environment = [
                {
                    name = "DAGSTER_POSTGRES_HOST"
                    value = data.terraform_remote_state.foundation.outputs.rds_endpoint
                }
            ]
            secrets = [
                {
                    name = "DAGSTER_POSTGRES_DB"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dagster_postgres_secret_arn}:db_name::"
                },
                {
                    name = "DAGSTER_POSTGRES_USER"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dagster_postgres_secret_arn}:username::"
                },
                {
                    name = "DAGSTER_POSTGRES_PASSWORD"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dagster_postgres_secret_arn}:password::"
                },
                {
                    name = "DBT_ENV_SECRET_SNOWFLAKE_ACCOUNT"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dbt_snowflake_secret_arn}:account::"
                },
                {
                    name = "DBT_ENV_SECRET_SNOWFLAKE_USER"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dbt_snowflake_secret_arn}:user::"
                },
                {
                    name = "DBT_ENV_SECRET_SNOWFLAKE_PRIVATE_KEY"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dbt_snowflake_secret_arn}:private_key::"
                },
                {
                    name = "DBT_ENV_SECRET_SNOWFLAKE_PRIVATE_KEY_PASSPHRASE"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dbt_snowflake_secret_arn}:private_key_passphrase::"
                },
            ]
            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    awslogs-group = "/ecs/${var.prefix}-dagster-ecs-daemon"
                    awslogs-region = data.aws_region.current.name
                    awslogs-stream-prefix = "ecs"
                }
            }
        }
    ])
}

resource "aws_ecs_service" "daemon" {
    name = "${var.prefix}-dagster-ecs-daemon"
    cluster = aws_ecs_cluster.main.id
    task_definition = aws_ecs_task_definition.daemon.arn
    desired_count = 1
    launch_type = "FARGATE"
    network_configuration {
        subnets = data.terraform_remote_state.foundation.outputs.private_subnet_ids
        security_groups = [data.terraform_remote_state.foundation.outputs.daemon_security_group_id]
        assign_public_ip = false
    }
}

# Service Discovery
resource "aws_service_discovery_private_dns_namespace" "main" {
    name = "${var.prefix}-dagster-ecs.internal"
    description = "Dagster Cloud Map Namespace"
    vpc = data.terraform_remote_state.foundation.outputs.vpc_id
}

resource "aws_service_discovery_service" "user_code" {
    name = "user-code"
    dns_config {
        namespace_id = aws_service_discovery_private_dns_namespace.main.id
        dns_records {
            type = "A"
            ttl = 10
        }
        routing_policy = "MULTIVALUE"
    }
    health_check_custom_config {
        failure_threshold = 1
    }
}

# User Code Task Definition and Service
resource "aws_ecs_task_definition" "user_code" {
    family = "${var.prefix}-dagster-ecs-user-code"
    network_mode = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    cpu = 512
    memory = 1024
    execution_role_arn = data.terraform_remote_state.foundation.outputs.execution_role_arn
    task_role_arn = data.terraform_remote_state.foundation.outputs.task_role_arn
    container_definitions = jsonencode([
        {
            name = "${var.prefix}-dagster-ecs-user-code"
            image = "${data.terraform_remote_state.foundation.outputs.user_code_ecr_repository_url}:latest"
            portMappings = [
                {
                    containerPort = 4000
                    protocol = "tcp"
                }
            ]
            environment = [
                {
                    name = "DAGSTER_POSTGRES_HOST"
                    value = data.terraform_remote_state.foundation.outputs.rds_endpoint
                },
                {
                    name = "DAGSTER_CURRENT_IMAGE"
                    value = "${data.terraform_remote_state.foundation.outputs.user_code_ecr_repository_url}:latest"
                },
                {
                    name = "DAGSTER_DBT_PARSE_PROJECT_ON_LOAD"
                    value = "1"
                }
            ]
            secrets = [
                {
                    name = "DBT_ENV_SECRET_SNOWFLAKE_ACCOUNT"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dbt_snowflake_secret_arn}:account::"
                },
                {
                    name = "DBT_ENV_SECRET_SNOWFLAKE_USER"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dbt_snowflake_secret_arn}:user::"
                },
                {
                    name = "DBT_ENV_SECRET_SNOWFLAKE_PRIVATE_KEY"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dbt_snowflake_secret_arn}:private_key::"
                },
                {
                    name = "DBT_ENV_SECRET_SNOWFLAKE_PRIVATE_KEY_PASSPHRASE"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dbt_snowflake_secret_arn}:private_key_passphrase::"
                },
                {
                    name = "DAGSTER_POSTGRES_DB"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dagster_postgres_secret_arn}:db_name::"
                },
                {
                    name = "DAGSTER_POSTGRES_USER"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dagster_postgres_secret_arn}:username::"
                },
                {
                    name = "DAGSTER_POSTGRES_PASSWORD"
                    valueFrom = "${data.terraform_remote_state.foundation.outputs.dagster_postgres_secret_arn}:password::"
                }
            ]
            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    awslogs-group = "/ecs/${var.prefix}-dagster-ecs-user-code"
                    awslogs-region = data.aws_region.current.name
                    awslogs-stream-prefix = "ecs"
                }
            }
        }
    ])
}

resource "aws_ecs_service" "user_code" {
    name = "${var.prefix}-dagster-ecs-user-code"
    cluster = aws_ecs_cluster.main.id
    task_definition = aws_ecs_task_definition.user_code.arn
    desired_count = 1
    launch_type = "FARGATE"
    network_configuration {
        subnets = data.terraform_remote_state.foundation.outputs.private_subnet_ids
        security_groups = [data.terraform_remote_state.foundation.outputs.user_code_security_group_id]
        assign_public_ip = false
    }
    service_registries {
        registry_arn = aws_service_discovery_service.user_code.arn
        container_name = "${var.prefix}-dagster-ecs-user-code"
    }
}