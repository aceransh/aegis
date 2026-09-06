output "db_address" {
  value = aws_db_instance.default.address
}

output "db_port" {
  value = aws_db_instance.default.port
}

output "db_name" {
  value = aws_db_instance.default.db_name
}
