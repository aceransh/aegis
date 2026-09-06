variable "subnets" {
  type = list(string)
}

variable "username" {
  type      = string
  sensitive = true
}

variable "password" {
  type      = string
  sensitive = true
}

variable "rds_security_group_id" {
  type = string
}

