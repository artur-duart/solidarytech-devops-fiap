resource "aws_ce_cost_allocation_tag" "this" {
  for_each = toset(module.finops_tags.cost_allocation_keys)

  tag_key = each.value
  status  = "Active"
}
