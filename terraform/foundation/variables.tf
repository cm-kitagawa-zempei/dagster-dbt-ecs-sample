variable "prefix" {
    description = "Resource name prefix"
    type = string
    default = "cm-kitagawa"
}


variable "vpc_cidr" {
    description = "VPC CIDR block"
    type = string
    default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
    description = "Public subnet CIDR blocks"
    type = list(string)
    default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
    description = "Private subnet CIDR blocks"
    type = list(string)
    default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "prefix_list_ids" {
    description = "Prefix list IDs for ALB security group"
    type = list(string)
    default = []
}

variable "dagster_postgres_db" {
    description = "Dagster DB name"
    type = string
}

variable "dagster_postgres_user" {
    description = "Dagster DB username"
    type = string
}

variable "dagster_postgres_password" {
    description = "Dagster DB password"
    type = string
    sensitive = true
}

variable "dbt_env_secret_snowflake_account" {
    description = "DBT env secret Snowflake account"
    type = string
}

variable "dbt_env_secret_snowflake_user" {
    description = "DBT env secret Snowflake user"
    type = string
}

variable "dbt_env_secret_snowflake_private_key" {
    description = "DBT env secret Snowflake private key"
    type = string
    sensitive = true
}

variable "dbt_env_secret_snowflake_private_key_passphrase" {
    description = "DBT env secret Snowflake private key passphrase"
    type = string
    sensitive = true
}