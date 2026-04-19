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
  description = "URI inicial da imagem do backend"
  default     = "nginx:latest" # placeholder até o primeiro deploy
}

variable "frontend_image" {
  description = "URI inicial da imagem do frontend"
  default     = "nginx:latest" # placeholder até o primeiro deploy
}

variable "backend_port" {
  default = 8080
}

variable "frontend_port" {
  default = 3000
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