output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.this.arn
}

output "task_role_arn" {
  value = aws_iam_role.task_role.arn
}

output "task_execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}

output "service_arn" {
  value = aws_ecs_service.this.arn
}

output "security_group_id" {
  value = aws_security_group.ecs.id
}
