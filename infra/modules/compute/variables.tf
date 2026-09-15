variable "cluster_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "compute_security_group_id" {
  type = string
}

variable "assign_public_ip" {
  type    = bool
  default = true
}

variable "db_dsn" {
  sensitive = true
  type      = string
}

variable "target_group_arn" {
  type    = string
  default = ""
}

variable "create_ecr_repos" {
  type    = bool
  default = true
}

variable "broker_image_url" {
  type    = string
  default = ""
}

variable "worker_image_url" {
  type    = string
  default = ""
}
