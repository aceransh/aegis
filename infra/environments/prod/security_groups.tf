data "aws_prefix_list" "s3" {
  name = "com.amazonaws.us-east-1.s3"
}

# All four security groups below are bare shells — no inline ingress/egress
# — because alb, compute, endpoints, and rds reference each other in both
# directions (alb -> compute, compute -> alb, compute -> endpoints,
# endpoints -> compute, compute -> rds, rds -> compute). Inline rules bake
# the reference into the SG resource itself, which creates a real
# dependency cycle Terraform can't resolve. Splitting each rule into its own
# aws_vpc_security_group_ingress_rule/egress_rule resource fixes it: the SGs
# themselves depend on nothing, so they can all be created first, and the
# rules (which do the cross-referencing) attach afterward.

resource "aws_security_group" "alb" {
  name   = "prod-alb-sg"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group" "compute" {
  name   = "prod-compute-sg"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group" "endpoints" {
  name   = "prod-endpoints-sg"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group" "rds" {
  name   = "prod-rds-sg"
  vpc_id = aws_vpc.main.id
}

# --- alb ---

resource "aws_vpc_security_group_ingress_rule" "alb_from_internet" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_compute" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.compute.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

# --- compute ---

resource "aws_vpc_security_group_ingress_rule" "compute_from_alb" {
  security_group_id            = aws_security_group.compute.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

# Interface endpoints (ECR api/dkr, CloudWatch Logs) sit on ENIs in the
# private-app subnets, so reaching them is a normal SG-to-SG rule.
resource "aws_vpc_security_group_egress_rule" "compute_to_endpoints" {
  security_group_id            = aws_security_group.compute.id
  referenced_security_group_id = aws_security_group.endpoints.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# S3 (backing ECR's actual image layers) is different: the Gateway endpoint
# isn't an ENI, so it can't be an SG rule's target the way a security group
# can — it's reached via a route to AWS's S3 prefix list, so this rule
# references that same prefix list instead of a security group.
resource "aws_vpc_security_group_egress_rule" "compute_to_s3" {
  security_group_id = aws_security_group.compute.id
  prefix_list_id    = data.aws_prefix_list.s3.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "compute_to_rds" {
  security_group_id            = aws_security_group.compute.id
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# --- endpoints ---

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_compute" {
  security_group_id            = aws_security_group.endpoints.id
  referenced_security_group_id = aws_security_group.compute.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# --- rds ---

resource "aws_vpc_security_group_ingress_rule" "rds_from_compute" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.compute.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}
