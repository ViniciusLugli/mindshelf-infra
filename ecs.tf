resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

data "external" "backend_latest_image" {
  depends_on = [aws_ecr_repository.backend]
  program    = ["python", "${path.module}/scripts/get_latest_ecr_digest.py"]

  query = {
    repository_name = aws_ecr_repository.backend.name
    region          = var.aws_region
  }
}

data "external" "frontend_latest_image" {
  depends_on = [aws_ecr_repository.frontend]
  program    = ["python", "${path.module}/scripts/get_latest_ecr_digest.py"]

  query = {
    repository_name = aws_ecr_repository.frontend.name
    region          = var.aws_region
  }
}

locals {
  backend_ecr_image  = data.external.backend_latest_image.result.image_digest != "" ? "${aws_ecr_repository.backend.repository_url}@${data.external.backend_latest_image.result.image_digest}" : null
  frontend_ecr_image = data.external.frontend_latest_image.result.image_digest != "" ? "${aws_ecr_repository.frontend.repository_url}@${data.external.frontend_latest_image.result.image_digest}" : null

  backend_container_image  = coalesce(var.backend_image, local.backend_ecr_image, "nginx:latest")
  frontend_container_image = coalesce(var.frontend_image, local.frontend_ecr_image, "nginx:latest")
}

# ─── BACKEND ───────────────────────────────────────────

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.backend_task_cpu
  memory                   = var.backend_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "backend"
    image     = local.backend_container_image
    essential = true

    portMappings = [{
      containerPort = var.backend_port
      protocol      = "tcp"
    }]

    environment = [
      { name = "NODE_ENV", value = "production" },
      { name = "LOG_LEVEL", value = var.backend_log_level },
      { name = "ALLOWED_ORIGINS", value = coalesce(var.backend_allowed_origins, "https://${var.domain_name},https://www.${var.domain_name}") },
      { name = "COOKIE_DOMAIN", value = ".${var.domain_name}" },
      { name = "COOKIE_SECURE", value = "true" }
    ]

    secrets = [
      {
        name      = "DATABASE_URL"
        valueFrom = aws_ssm_parameter.backend_database_url.arn
      },
      {
        name      = "DSN"
        valueFrom = aws_ssm_parameter.backend_dsn.arn
      },
      {
        name      = "JWT_SECRET"
        valueFrom = aws_ssm_parameter.backend_jwt_secret.arn
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/${var.project_name}/backend"
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}/backend"
  retention_in_days = 7
}

resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_desired_count
  launch_type     = "FARGATE"
  depends_on      = [aws_lb_listener.https]

  health_check_grace_period_seconds = 120

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = var.backend_port
  }
}

# ─── FRONTEND ──────────────────────────────────────────

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.frontend_task_cpu
  memory                   = var.frontend_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name      = "frontend"
    image     = local.frontend_container_image
    essential = true

    portMappings = [{
      containerPort = var.frontend_port
      protocol      = "tcp"
    }]

    environment = [
      { name = "API_ORIGIN", value = "https://api.${var.domain_name}" },
      { name = "NEXT_PUBLIC_WS_PATH", value = "/api/ws" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/${var.project_name}/frontend"
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project_name}/frontend"
  retention_in_days = 7
}

resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.frontend_desired_count
  launch_type     = "FARGATE"
  depends_on      = [aws_lb_listener.https]

  health_check_grace_period_seconds = 60

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = var.frontend_port
  }
}
