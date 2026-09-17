locals {
  # ECR repo names are unique per account+region, not per VPC — a second
  # environment can't create its own "broker"/"worker" repos without
  # colliding with the first. create_ecr_repos lets a caller (prod) skip
  # creation and hand in an already-existing repo URL instead.
  broker_repo_url = var.create_ecr_repos ? aws_ecr_repository.broker[0].repository_url : var.broker_image_url
  worker_repo_url = var.create_ecr_repos ? aws_ecr_repository.worker[0].repository_url : var.worker_image_url
}

resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.main.arn
  }
}

resource "aws_service_discovery_http_namespace" "main" {
  # Cloud Map HTTP namespaces are account+region scoped (no VPC
  # association), so this needs to be unique across environments too.
  name = "${var.cluster_name}-main"
}

resource "aws_iam_role" "main" {
  # Same reasoning as the namespace above — IAM role names are account-wide
  # unique, not scoped per VPC.
  name = "${var.cluster_name}-task-exec-role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "main" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "broker" {
  family                   = "broker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.main.arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "${local.broker_repo_url}:latest"

      portMappings = [
        {
          name          = "broker"
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DB_DSN"
          value = var.db_dsn
        },
        {
          name  = "AUTH_TOKEN"
          value = var.auth_token
        }
      ]
    }
  ])

}

resource "aws_ecs_task_definition" "worker" {
  family                   = "worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.main.arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "${local.worker_repo_url}:latest"

      environment = [
        {
          name  = "BROKER_URL"
          value = "http://broker:8080"
        },
        {
          name  = "AUTH_TOKEN"
          value = var.auth_token
        }
      ]
    }
  ])

}

resource "aws_ecs_service" "broker" {
  name            = "broker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.broker.arn
  desired_count   = 1
  depends_on      = [aws_iam_role_policy_attachment.main]
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = var.assign_public_ip
    security_groups  = [var.compute_security_group_id]
    subnets          = var.subnet_ids
  }

  # Empty for cost (no ALB) — for prod, target_group_arn is set and this
  # attaches the service to the ALB's target group.
  dynamic "load_balancer" {
    for_each = var.target_group_arn != "" ? [var.target_group_arn] : []
    content {
      target_group_arn = load_balancer.value
      container_name   = "app"
      container_port   = 8080
    }
  }

  service_connect_configuration {
    enabled = true
    service {
      port_name = "broker"
      client_alias {
        dns_name = "broker"
        port     = 8080
      }
    }
  }
}

resource "aws_ecs_service" "worker" {
  name            = "worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = 0
  depends_on      = [aws_iam_role_policy_attachment.main]
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = var.assign_public_ip
    security_groups  = [var.compute_security_group_id]
    subnets          = var.subnet_ids
  }

  service_connect_configuration {
    enabled = true
  }
}

resource "aws_ecr_repository" "broker" {
  count        = var.create_ecr_repos ? 1 : 0
  name         = "broker"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "worker" {
  count        = var.create_ecr_repos ? 1 : 0
  name         = "worker"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}
