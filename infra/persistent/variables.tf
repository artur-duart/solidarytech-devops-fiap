variable "aws_region" {
  description = "Região da AWS onde os recursos persistentes serão criados."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nome do projeto, usado na tag Project e no prefixo dos recursos."
  type        = string
  default     = "SolidaryTech"
}

variable "environment" {
  description = "Ambiente, usado na tag Environment."
  type        = string
  default     = "Production"

  validation {
    condition     = contains(["Production", "Staging", "Development"], var.environment)
    error_message = "Environment deve ser Production, Staging ou Development."
  }
}

variable "cost_center" {
  description = "Centro de custo, usado na tag CostCenter."
  type        = string
  default     = "NGO-Core"

  validation {
    condition     = can(regex("^NGO-[A-Za-z]+$", var.cost_center))
    error_message = "CostCenter deve seguir o padrão NGO-<Area>, por exemplo NGO-Core."
  }
}

variable "owner" {
  description = "Responsável pelos recursos, usado na tag Owner."
  type        = string
  default     = "artur-duart"
}
