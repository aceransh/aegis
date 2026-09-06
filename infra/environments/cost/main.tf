variable "username" {
  sensitive = true
  type      = string
}

variable "password" {
  sensitive = true
  type      = string
}

locals {
  db_dsn = "host=${module.database.db_address} port=${module.database.db_port} user=${var.username} password=${var.password} dbname=${module.database.db_name} sslmode=require"
}

module "networking" {
  source = "../../modules/networking"
}

module "compute" {
  source                    = "../../modules/compute"
  cluster_name              = "cost"
  public_subnet_id          = module.networking.public_subnet_id
  compute_security_group_id = module.networking.compute_security_group_id
  db_dsn                    = local.db_dsn
}

module "database" {
  source                = "../../modules/database"
  subnets               = [module.networking.private_subnet_id1, module.networking.private_subnet_id2]
  username              = var.username
  password              = var.password
  rds_security_group_id = module.networking.rds_security_group_id
}

resource "aws_budgets_budget" "cost" {
  name         = "budget-aegis-monthly"
  budget_type  = "COST"
  limit_amount = "5"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["anshdesai@me.com"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["anshdesai@me.com"]
  }
}

output "aws_ecr_repository_broker" {
  value = module.compute.aws_ecr_repository_broker_repo_url
}

output "aws_ecr_repository_worker" {
  value = module.compute.aws_ecr_repository_worker_repo_url
}
