locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    CostCenter  = var.cost_center
    Owner       = var.owner
    ManagedBy   = "Terraform"
    Stack       = var.stack
  }
}

output "tags" {
  description = "Tags obrigatórias, no formato usado pelo default_tags do provider AWS."
  value       = local.tags
}

output "name_prefix" {
  description = "Prefixo em minúsculas para o nome dos recursos."
  value       = lower(var.project)
}

output "cost_allocation_keys" {
  description = "Chaves que devem estar ativadas como tags de alocação de custo no Billing."
  value       = concat(keys(local.tags), ["Service"])
}

output "kubernetes_annotation" {
  description = "Tags no formato chave=valor separado por vírgula, usado em anotações de load balancer do Kubernetes."
  value       = join(",", [for k, v in local.tags : "${k}=${v}"])
}
