output "url" {
  value       = format("http://%s%s", local.hostname, var.url_path)
  description = "The URL of the service"
}

output "ecs_service_name" {
  value       = aws_ecs_service.default.name
  description = "The ECS service name"
}

output "ecs_service_cluster" {
  value       = aws_ecs_service.default.cluster
  description = "The ECS cluster ARN associated with the service"
}

output "task_definition_arn" {
  value       = aws_ecs_task_definition.default.arn
  description = "The ECS task definition ARN"
}
