locals {
  app_namespace = "solidarytech"

  irsa = {
    donation = {
      namespace       = local.app_namespace
      service_account = "donation-sa"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = ["sqs:SendMessage"]
          Resource = aws_sqs_queue.donation_events.arn
        }]
      })
    }
    volunteer = {
      namespace       = local.app_namespace
      service_account = "volunteer-sa"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = ["dynamodb:PutItem", "dynamodb:Scan"]
          Resource = aws_dynamodb_table.volunteers.arn
        }]
      })
    }
    load-balancer-controller = {
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
      policy          = file("${path.module}/policies/aws-load-balancer-controller.json")
    }
  }
}

data "aws_iam_policy_document" "irsa_assume" {
  for_each = local.irsa

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each = local.irsa

  name               = "${local.name}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume[each.key].json
}

resource "aws_iam_role_policy" "irsa" {
  for_each = local.irsa

  name   = "${local.name}-${each.key}"
  role   = aws_iam_role.irsa[each.key].id
  policy = each.value.policy
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = local.app_namespace
  }
}

resource "kubernetes_service_account" "app" {
  for_each = { for k, v in local.irsa : k => v if v.namespace == local.app_namespace }

  metadata {
    name      = each.value.service_account
    namespace = kubernetes_namespace.app.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.irsa[each.key].arn
    }
  }
}
