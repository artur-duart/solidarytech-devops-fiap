provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      CostCenter  = var.cost_center
      Owner       = var.owner
      ManagedBy   = "Terraform"
      Stack       = "bootstrap"
    }
  }
}
