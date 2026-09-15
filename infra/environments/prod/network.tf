resource "aws_vpc" "main" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "aegis-prod"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "prod-public-b"
  }
}

resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-private-app-a"
  }
}

resource "aws_subnet" "private_app_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.12.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "prod-private-app-b"
  }
}

resource "aws_subnet" "private_data_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.21.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-private-data-a"
  }
}

resource "aws_subnet" "private_data_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.22.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "prod-private-data-b"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "aegis-prod"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "prod-public"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Deliberately no 0.0.0.0/0 route — PrivateLink (endpoints.tf) covers
# everything compute needs to reach, so there's nothing to send to the
# internet. The S3 gateway endpoint adds its own route to this table below.
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "prod-private-app"
  }
}

resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private_app_a.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table_association" "private_app_b" {
  subnet_id      = aws_subnet.private_app_b.id
  route_table_id = aws_route_table.private_app.id
}

# private_data (RDS) subnets are left on the VPC's implicit default route
# table on purpose — an unassociated subnet falls back to it automatically,
# and it only carries the local route. That's exactly "no egress at all,"
# and RDS never needs to reach anything outbound, so no explicit route
# table is needed here the way private_app needed one for the S3 endpoint.
