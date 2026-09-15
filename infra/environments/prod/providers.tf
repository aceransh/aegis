terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::850995546417:role/aegis-admin-role"
    session_name = "TerraformAegisSession"
  }
}
