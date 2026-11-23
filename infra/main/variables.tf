variable "aws_region" {
  description = "Região da AWS onde o ambiente principal será criado."
  type        = string
  default     = "us-east-1"
}

variable "admin_cidrs" {
  description = "Faixas autorizadas a acessar a API do EKS. Vazio usa o IP público de quem executa o Terraform."
  type        = list(string)
  default     = []
}

variable "kubernetes_version" {
  description = "Versão do Kubernetes no EKS."
  type        = string
  default     = "1.36"
}

variable "node_instance_types" {
  description = "Tipos de instância dos nós do cluster."
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_scaling" {
  description = "Quantidade mínima, desejada e máxima de nós."
  type = object({
    min     = number
    desired = number
    max     = number
  })
  default = {
    min     = 1
    desired = 2
    max     = 4
  }
}

variable "db_instance_class" {
  description = "Classe das instâncias RDS."
  type        = string
  default     = "db.t4g.micro"
}
