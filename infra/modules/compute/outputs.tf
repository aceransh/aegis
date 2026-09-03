output "aws_ecr_repository_broker_repo_url" {
  value = aws_ecr_repository.broker.repository_url
}

output "aws_ecr_repository_worker_repo_url" {
  value = aws_ecr_repository.worker.repository_url
}
