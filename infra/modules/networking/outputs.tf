output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id1" {
  value = aws_subnet.private1.id
}

output "private_subnet_id2" {
  value = aws_subnet.private2.id
}

output "compute_security_group_id" {
  value = aws_security_group.compute.id
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}
