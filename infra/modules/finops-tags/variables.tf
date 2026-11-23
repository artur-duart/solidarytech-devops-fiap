variable "project" {
  description = "Projeto dono do recurso (tag Project)."
  type        = string
  default     = "SolidaryTech"

  validation {
    condition     = var.project == "SolidaryTech"
    error_message = "Project deve ser SolidaryTech."
  }
}

variable "environment" {
  description = "Ambiente do recurso (tag Environment)."
  type        = string
  default     = "Production"

  validation {
    condition     = contains(["Production", "Staging", "Development"], var.environment)
    error_message = "Environment deve ser Production, Staging ou Development."
  }
}

variable "cost_center" {
  description = "Centro de custo que paga o recurso (tag CostCenter)."
  type        = string
  default     = "NGO-Core"

  validation {
    condition     = can(regex("^NGO-[A-Z][A-Za-z]+$", var.cost_center))
    error_message = "CostCenter deve seguir o padrão NGO-<Area>, por exemplo NGO-Core."
  }
}

variable "owner" {
  description = "Responsável técnico pelo recurso (tag Owner)."
  type        = string
  default     = "artur-duart"

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "Owner não pode ficar vazio."
  }
}

variable "stack" {
  description = "Stack do Terraform que criou o recurso (tag Stack)."
  type        = string

  validation {
    condition     = contains(["bootstrap", "persistent", "main", "dr"], var.stack)
    error_message = "Stack deve ser bootstrap, persistent, main ou dr."
  }
}
