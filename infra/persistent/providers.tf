provider "aws" {
  region = var.aws_region

  default_tags {
    tags = module.finops_tags.tags
  }
}
