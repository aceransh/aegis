variable "username" {
  sensitive = true
  type      = string
}

variable "password" {
  sensitive = true
  type      = string
}

variable "auth_token" {
  sensitive = true
  type      = string
}

locals {
  db_dsn = "host=${module.database.db_address} port=${module.database.db_port} user=${var.username} password=${var.password} dbname=${module.database.db_name} sslmode=require"
}

# ECR repos are shared across environments — the same images deploy to both
# cost and prod, and repo names are account+region unique, so prod looks up
# cost's existing repos instead of creating its own (which would collide).
data "aws_ecr_repository" "broker" {
  name = "broker"
}

data "aws_ecr_repository" "worker" {
  name = "worker"
}

module "compute" {
  source                    = "../../modules/compute"
  cluster_name              = "prod"
  subnet_ids                = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]
  compute_security_group_id = aws_security_group.compute.id
  assign_public_ip          = false
  db_dsn                    = local.db_dsn
  target_group_arn          = aws_lb_target_group.broker.arn
  create_ecr_repos          = false
  broker_image_url          = data.aws_ecr_repository.broker.repository_url
  worker_image_url          = data.aws_ecr_repository.worker.repository_url
  auth_token                = var.auth_token
}

module "database" {
  source                = "../../modules/database"
  subnets               = [aws_subnet.private_data_a.id, aws_subnet.private_data_b.id]
  username              = var.username
  password              = var.password
  rds_security_group_id = aws_security_group.rds.id
  multi_az              = true
}

output "alb_dns_name" {
  value = aws_lb.broker.dns_name
}
