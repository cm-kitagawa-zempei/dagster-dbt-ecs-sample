# VPC
resource "aws_vpc" "main" {
    cidr_block = var.vpc_cidr
    enable_dns_support = true
    enable_dns_hostnames = true
}

# Availability Zones
data "aws_availability_zones" "available" {
    state = "available"
}

# Public Subnets
resource "aws_subnet" "public" {
    count = length(var.public_subnet_cidrs)
    vpc_id = aws_vpc.main.id
    cidr_block = var.public_subnet_cidrs[count.index]
    map_public_ip_on_launch = true
    availability_zone = data.aws_availability_zones.available.names[count.index]
}

# Private Subnets
resource "aws_subnet" "private" {
    count = length(var.private_subnet_cidrs)
    vpc_id = aws_vpc.main.id
    cidr_block = var.private_subnet_cidrs[count.index]
    availability_zone = data.aws_availability_zones.available.names[count.index]
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id
}

# Public Route Table
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id
}

# Public Internet Access Route
resource "aws_route" "public_internet_access" {
    route_table_id = aws_route_table.public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
}

# Public Subnet Route Table Association
resource "aws_route_table_association" "public" {
    count = length(aws_subnet.public)
    subnet_id = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
}

# NAT Gateway Elastic IP
resource "aws_eip" "nat" {
    domain = "vpc"
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
    allocation_id = aws_eip.nat.id
    subnet_id = aws_subnet.public[0].id
}

# Private Route Table
resource "aws_route_table" "private" {
    vpc_id = aws_vpc.main.id
}

# Private NAT Gateway Route
resource "aws_route" "private_nat_gateway" {
    route_table_id = aws_route_table.private.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
}

# Private Subnet Route Table Association
resource "aws_route_table_association" "private" {
    count = length(aws_subnet.private)
    subnet_id = aws_subnet.private[count.index].id
    route_table_id = aws_route_table.private.id
}

# Security Groups
resource "aws_security_group" "alb" {
    name = "${var.prefix}-dagster-ecs-alb-sg"
    description = "Allow HTTP/HTTPS traffic to ALB"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = []
        prefix_list_ids = ["pl-xxxxxxxxxxxxxxxxx"]  # 必要に応じて設定
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "web" {
    name = "${var.prefix}-dagster-ecs-web-sg"
    description = "Allow HTTP/HTTPS traffic from ALB"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        security_groups = [aws_security_group.alb.id]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "daemon" {
    name = "${var.prefix}-dagster-ecs-daemon-sg"
    vpc_id = aws_vpc.main.id

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "user_code" {
    name = "${var.prefix}-dagster-ecs-user-code-sg"
    vpc_id = aws_vpc.main.id
    
    ingress {
        from_port = 4000
        to_port = 4000
        protocol = "tcp"
        security_groups = [aws_security_group.web.id, aws_security_group.daemon.id]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "rds" {
    name = "${var.prefix}-dagster-ecs-rds-sg"
    description = "Allow PostgreSQL from ECS"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        security_groups = [aws_security_group.web.id, aws_security_group.daemon.id, aws_security_group.user_code.id]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# RDS
resource "aws_db_subnet_group" "main" {
    name = "${var.prefix}-dagster-ecs-db-subnet-group"
    subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "main" {
    identifier = "${var.prefix}-dagster-ecs-db"
    db_name = var.dagster_postgres_db
    engine = "postgres"
    engine_version = "17.2"
    instance_class = "db.m5.large"
    allocated_storage = 20
    username = var.dagster_postgres_user
    password = var.dagster_postgres_password
    port = 5432
    db_subnet_group_name = aws_db_subnet_group.main.name
    vpc_security_group_ids = [aws_security_group.rds.id]
    skip_final_snapshot = true
    publicly_accessible = false
    multi_az = false
    storage_encrypted = true
    deletion_protection = false
    tags = {
        "cm-daily-stop" = "true"
    }
}

# ECR Repositories
resource "aws_ecr_repository" "dagster" {
    name = "${var.prefix}-dagster_ecs_core"
    image_scanning_configuration {
        scan_on_push = true
    }
}

resource "aws_ecr_repository" "user_code" {
    name = "${var.prefix}-dagster_ecs_user_code"
    image_scanning_configuration {
        scan_on_push = true
    }
}

# IAM Roles and Policies
resource "aws_iam_role" "task" {
    name_prefix = "${var.prefix}-dagster-ecs-task-"
    description = "Role for Dagster ECS tasks"

    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Principal = {Service = "ecs-tasks.amazonaws.com"},
                Action = "sts:AssumeRole"
            }
        ]
    })
}

resource "aws_iam_policy" "task" {
    name_prefix = "${var.prefix}-dagster-ecs-task-"
    description = "Policy for Dagster ECS tasks"
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Action = [
                    "iam:PassRole",
                    "ecs:RunTask",
                    "ecs:DescribeTasks",
                    "ecs:DescribeTaskDefinition",
                    "ecs:RegisterTaskDefinition",
                    "ecs:ListTasks",
                    "ecs:StopTask",
                    "ecs:TagResource",
                    "ec2:DescribeNetworkInterfaces",
                    "secretsmanager:GetSecretValue",
                    "secretsmanager:DescribeSecret",
                    "secretsmanager:ListSecrets",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "logs:CreateLogGroup",
                    "logs:DescribeLogStreams",
                ],
                Resource = "*"
            },
        ],
    })
}

resource "aws_iam_role_policy_attachment" "task" {
    role       = aws_iam_role.task.name
    policy_arn = aws_iam_policy.task.arn
}


resource "aws_iam_role" "execution" {
    name_prefix = "${var.prefix}-dagster-ecs-execution-"
    description = "Role for ECS task execution"

    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Principal = {
                    Service = "ecs-tasks.amazonaws.com"
                },
                Action = "sts:AssumeRole"
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "execution-AmazonECSTaskExecutionRolePolicy" {
    role       = aws_iam_role.execution.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "execution" {
    name_prefix = "${var.prefix}-dagster-ecs-execution-"
    description = "Policy for ECS execution role with ECR permissions"
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Action = [
                    "ecr:GetAuthorizationToken",
                    "ecr:BatchCheckLayerAvailability",
                    "ecr:GetDownloadUrlForLayer",
                    "ecr:BatchGetImage",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "logs:CreateLogGroup",
                    "logs:DescribeLogStreams",
                    "secretsmanager:GetSecretValue",
                    "secretsmanager:DescribeSecret",
                    "secretsmanager:ListSecrets",
                ],
                Resource = "*"
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "dagster-ecs-execution-role-policy-attachment" {
    role       = aws_iam_role.execution.name
    policy_arn = aws_iam_policy.execution.arn
}


# Secrets Manager
resource "aws_secretsmanager_secret" "dbt_env_secret_snowflake" {
    name = "${var.prefix}-dbt_env_secret_snowflake"
}

resource "aws_secretsmanager_secret_version" "dbt_env_secret_snowflake" {
    secret_id = aws_secretsmanager_secret.dbt_env_secret_snowflake.id
    secret_string = jsonencode({
        account = var.dbt_env_secret_snowflake_account
        user = var.dbt_env_secret_snowflake_user
        private_key = var.dbt_env_secret_snowflake_private_key
        private_key_passphrase = var.dbt_env_secret_snowflake_private_key_passphrase
    })
}

resource "aws_secretsmanager_secret" "dagster_postgres" {
    name = "${var.prefix}-dagster_postgres"
}

resource "aws_secretsmanager_secret_version" "dagster_postgres" {
    secret_id = aws_secretsmanager_secret.dagster_postgres.id
    secret_string = jsonencode({
        db_name = var.dagster_postgres_db
        username = var.dagster_postgres_user
        password = var.dagster_postgres_password
    })
}