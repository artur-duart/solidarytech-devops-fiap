module "finops_tags" {
  source = "../modules/finops-tags"
  stack  = "main"
}

locals {
  name = module.finops_tags.name_prefix
  tags = module.finops_tags.tags
}
