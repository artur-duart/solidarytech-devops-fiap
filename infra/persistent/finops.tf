variable "alert_email" {
  description = "E-mail que recebe os alertas de custo. Informe via TF_VAR_alert_email."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email deve ser um endereço de e-mail válido."
  }
}

variable "monthly_usage_budget_usd" {
  description = "Teto mensal de consumo bruto, antes dos créditos, em dólares."
  type        = number
  default     = 40
}

resource "aws_ce_cost_allocation_tag" "this" {
  for_each = toset(module.finops_tags.cost_allocation_keys)

  tag_key = each.value
  status  = "Active"
}

resource "aws_budgets_budget" "consumo_bruto" {
  name         = "${module.finops_tags.name_prefix}-consumo-bruto"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_usage_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit = false
    include_refund = false
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}

resource "aws_budgets_budget" "gasto_real" {
  name         = "${module.finops_tags.name_prefix}-gasto-real"
  budget_type  = "COST"
  limit_amount = "1"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit = true
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 0.01
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}

resource "aws_ce_anomaly_monitor" "projeto" {
  name         = "${module.finops_tags.name_prefix}-anomalias"
  monitor_type = "CUSTOM"

  monitor_specification = jsonencode({
    Tags = {
      Key          = "Project"
      Values       = [module.finops_tags.tags.Project]
      MatchOptions = ["EQUALS"]
    }
  })
}

resource "aws_ce_anomaly_subscription" "projeto" {
  name             = "${module.finops_tags.name_prefix}-anomalias"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.projeto.arn]

  subscriber {
    type    = "EMAIL"
    address = var.alert_email
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      values        = ["3"]
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }
}
