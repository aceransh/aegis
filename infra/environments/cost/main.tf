module "networking" {
  source = "../../modules/networking"
}

module "compute" {
  source                    = "../../modules/compute"
  cluster_name              = "cost"
  public_subnet_id          = module.networking.public_subnet_id
  compute_security_group_id = module.networking.compute_security_group_id
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
