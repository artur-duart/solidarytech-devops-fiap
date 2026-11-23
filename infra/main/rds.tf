resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds"
  description = "Libera PostgreSQL apenas a partir dos nos do EKS"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_nodes" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL a partir dos nos do EKS"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.eks.node_security_group_id
}

resource "aws_kms_key" "rds" {
  description         = "Chave de criptografia dos bancos RDS da SolidaryTech"
  enable_key_rotation = true
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

locals {
  databases = {
    ngo = {
      service          = "ngo-service"
      db_name          = "ngo_db"
      username         = "ngo_user"
      backup_retention = 1
    }
    donation = {
      service          = "donation-service"
      db_name          = "donation_db"
      username         = "donation_user"
      backup_retention = 7
    }
  }
}

resource "aws_db_instance" "this" {
  for_each = local.databases

  identifier = "${local.name}-${each.key}"
  db_name    = each.value.db_name
  username   = each.value.username

  engine            = "postgres"
  engine_version    = "17"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp3"

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false

  storage_encrypted                   = true
  kms_key_id                          = aws_kms_key.rds.arn
  manage_master_user_password         = true
  iam_database_authentication_enabled = true

  backup_retention_period = each.value.backup_retention
  copy_tags_to_snapshot   = true
  skip_final_snapshot     = true

  tags = {
    Service = each.value.service
  }
}
