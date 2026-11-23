output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = module.eks.cluster_name
}

output "vpc_id" {
  description = "ID da VPC."
  value       = module.vpc.vpc_id
}

output "rds_endpoints" {
  description = "Endpoint de cada banco RDS."
  value       = { for k, db in aws_db_instance.this : k => db.address }
}

output "rds_master_secret_arns" {
  description = "ARN do segredo no Secrets Manager com a senha de cada banco."
  value       = { for k, db in aws_db_instance.this : k => db.master_user_secret[0].secret_arn }
}

output "donation_events_queue_url" {
  description = "URL da fila de eventos de doação."
  value       = aws_sqs_queue.donation_events.url
}

output "volunteers_table" {
  description = "Nome da tabela de voluntários."
  value       = aws_dynamodb_table.volunteers.name
}

output "irsa_role_arns" {
  description = "ARN da role de cada service account."
  value       = { for k, r in aws_iam_role.irsa : k => r.arn }
}
