variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "meu-projeto"
}

variable "domain_name" {
  description = "Seu domínio, ex: meusite.com"
}

variable "backend_image" {
  description = "Override opcional da imagem do backend. Se nulo, tenta a ultima imagem publicada no ECR e cai para nginx:latest como fallback."
  type        = string
  default     = null
  nullable    = true
}

variable "frontend_image" {
  description = "Override opcional da imagem do frontend. Se nulo, tenta a ultima imagem publicada no ECR e cai para nginx:latest como fallback."
  type        = string
  default     = null
  nullable    = true
}

variable "backend_port" {
  default = 8080
}

variable "backend_task_cpu" {
  description = "CPU units para task do backend no ECS Fargate"
  type        = number
  default     = 512
}

variable "backend_task_memory" {
  description = "Memoria (MiB) para task do backend no ECS Fargate"
  type        = number
  default     = 1024
}

variable "backend_desired_count" {
  description = "Quantidade desejada de tasks do backend"
  type        = number
  default     = 1
}

variable "frontend_port" {
  default = 3000
}

variable "frontend_task_cpu" {
  description = "CPU units para task do frontend no ECS Fargate"
  type        = number
  default     = 256
}

variable "frontend_task_memory" {
  description = "Memoria (MiB) para task do frontend no ECS Fargate"
  type        = number
  default     = 512
}

variable "frontend_desired_count" {
  description = "Quantidade desejada de tasks do frontend"
  type        = number
  default     = 1
}

variable "backend_log_level" {
  description = "Nível de log do backend"
  default     = "info"
}

variable "backend_allowed_origins" {
  description = "Origens permitidas no CORS (ex: http://localhost:3000)"
  type        = string
  default     = null
}

variable "backend_jwt_secret" {
  description = "Segredo JWT do backend"
  type        = string
  sensitive   = true
}

variable "db_name" {
  default = "mindshelf"
}

variable "db_username" {
  default = "mindshelf"
}

variable "db_instance_class" {
  default = "db.t4g.micro"
}

variable "db_engine_version" {
  default = "16.3"
}

variable "db_allocated_storage" {
  default = 20
}

variable "db_max_allocated_storage" {
  default = 100
}

variable "db_multi_az" {
  default = false
}

variable "db_backup_retention_period" {
  default = 7
}

variable "db_deletion_protection" {
  default = false
}

variable "db_skip_final_snapshot" {
  default = true
}
