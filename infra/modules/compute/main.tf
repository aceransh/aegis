resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.main.arn
  }
}

resource "aws_service_discovery_http_namespace" "main" {
  name = "main"
}

resource "aws_iam_role" "main" {
  name = "task-exec-role"

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
      image = "${aws_ecr_repository.broker.repository_url}:latest"

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
      image = "${aws_ecr_repository.worker.repository_url}:latest"

      environment = [
        {
          name  = "BROKER_URL"
          value = "http://broker:8080"
        }
      ]
    }
  ])

}

resource "aws_ecs_service" "broker" {
  name            = "broker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.broker.arn
  desired_count   = 0
  depends_on      = [aws_iam_role_policy_attachment.main]
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    security_groups  = [var.compute_security_group_id]
    subnets          = [var.public_subnet_id]
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
    assign_public_ip = true
    security_groups  = [var.compute_security_group_id]
    subnets          = [var.public_subnet_id]
  }

  service_connect_configuration {
    enabled = true
  }
}

resource "aws_ecr_repository" "broker" {
  name         = "broker"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "worker" {
  name         = "worker"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

