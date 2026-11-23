data "http" "ip_publico" {
  url = "https://checkip.amazonaws.com"
}

locals {
  admin_cidrs = length(var.admin_cidrs) > 0 ? var.admin_cidrs : ["${chomp(data.http.ip_publico.response_body)}/32"]
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  vpc_id                       = module.vpc.vpc_id
  subnet_ids                   = module.vpc.public_subnets
  endpoint_public_access       = true
  endpoint_public_access_cidrs = local.admin_cidrs

  enable_cluster_creator_admin_permissions = true

  enabled_log_types                      = ["audit"]
  cloudwatch_log_group_retention_in_days = 7

  addons = {
    vpc-cni = {
      before_compute = true
    }
    kube-proxy = {}
    coredns    = {}
    aws-ebs-csi-driver = {
      service_account_role_arn = aws_iam_role.ebs_csi.arn
      configuration_values = jsonencode({
        controller = {
          extraVolumeTags = local.tags
        }
      })
    }
  }

  eks_managed_node_groups = {
    default = {
      subnet_ids     = module.vpc.private_subnets
      instance_types = var.node_instance_types
      min_size       = var.node_scaling.min
      desired_size   = var.node_scaling.desired
      max_size       = var.node_scaling.max

      launch_template_tags = local.tags
    }
  }
}

data "aws_iam_policy_document" "ebs_csi_assume" {
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
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${local.name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
