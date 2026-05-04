resource "random_password" "postgres_password" {
  length  = 24
  special = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_db_subnet_group" "postgres" {
  name       = "${var.project_name}-postgres-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.project_name}-postgres-subnet-group"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_security_group" "rds_postgres" {
  name        = "${var.project_name}-rds-postgres-sg"
  description = "Permite acesso ao Postgres apenas do ECS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Postgres vindo do ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-postgres-sg"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-postgres"

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.postgres_password.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds_postgres.id]
  publicly_accessible    = false

  multi_az                   = var.db_multi_az
  backup_retention_period    = var.db_backup_retention_period
  auto_minor_version_upgrade = true
  apply_immediately          = true

  deletion_protection = var.db_deletion_protection
  skip_final_snapshot = var.db_skip_final_snapshot

  tags = {
    Name = "${var.project_name}-postgres"
  }

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  postgres_host = aws_db_instance.postgres.address
  postgres_port = aws_db_instance.postgres.port

  database_url = "postgres://${var.db_username}:${random_password.postgres_password.result}@${local.postgres_host}:${local.postgres_port}/${var.db_name}?sslmode=require"
  dsn          = "host=${local.postgres_host} port=${local.postgres_port} user=${var.db_username} password=${random_password.postgres_password.result} dbname=${var.db_name} sslmode=require"
}

resource "aws_ssm_parameter" "backend_database_url" {
  name        = "/${var.project_name}/backend/DATABASE_URL"
  description = "DATABASE_URL do backend"
  type        = "SecureString"
  value       = local.database_url

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ssm_parameter" "backend_dsn" {
  name        = "/${var.project_name}/backend/DSN"
  description = "DSN do backend"
  type        = "SecureString"
  value       = local.dsn

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ssm_parameter" "backend_jwt_secret" {
  name        = "/${var.project_name}/backend/JWT_SECRET"
  description = "JWT_SECRET do backend"
  type        = "SecureString"
  value       = var.backend_jwt_secret

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ssm_parameter" "backend_db_host" {
  name        = "/${var.project_name}/backend/DB_HOST"
  description = "Host do banco"
  type        = "String"
  value       = local.postgres_host

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ssm_parameter" "backend_db_port" {
  name        = "/${var.project_name}/backend/DB_PORT"
  description = "Porta do banco"
  type        = "String"
  value       = tostring(local.postgres_port)

  lifecycle {
    prevent_destroy = true
  }
}
