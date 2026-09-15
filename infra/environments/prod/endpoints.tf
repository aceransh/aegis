resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

# Gateway type, not Interface — attaches to a route table, not an ENI/SG, and
# is free (no hourly charge, no per-GB charge). Carries the highest-volume
# traffic in this design: ECR's actual image layer bytes are S3-backed, so
# this is the endpoint that made PrivateLink win the checkpoint-1 decision.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_app.id]
}
