# ALB
output "alb_dns_name" {
    description = "ALB DNS name"
    value = aws_lb.main.dns_name
}

output "alb_zone_id" {
    description = "ALB zone ID"
    value = aws_lb.main.zone_id
}

output "dagster_url" {
    description = "Dagster web interface URL"
    value = "http://${aws_lb.main.dns_name}"
}

# ECS
output "ecs_cluster_name" {
    description = "ECS cluster name"
    value = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
    description = "ECS cluster ARN"
    value = aws_ecs_cluster.main.arn
}

# Service Discovery
output "service_discovery_namespace_id" {
    description = "Service discovery namespace ID"
    value = aws_service_discovery_private_dns_namespace.main.id
}

output "user_code_service_discovery_service_arn" {
    description = "User code service discovery service ARN"
    value = aws_service_discovery_service.user_code.arn
}