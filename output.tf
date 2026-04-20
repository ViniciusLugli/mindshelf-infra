output "alb_dns" {
  description = "DNS do Load Balancer"
  value       = aws_lb.main.dns_name
}

output "site_url" {
  description = "URL do site"
  value       = "https://${var.domain_name}"
}

output "api_url" {
  description = "URL publica da API"
  value       = "https://api.${var.domain_name}"
}

output "ecr_backend_url" {
  description = "URL do repositório ECR do backend"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_url" {
  description = "URL do repositório ECR do frontend"
  value       = aws_ecr_repository.frontend.repository_url
}

output "route53_nameservers" {
  description = "Nameservers para configurar no seu registrar"
  value       = aws_route53_zone.main.name_servers
}

output "postgres_endpoint" {
  value = aws_db_instance.postgres.address
}

output "postgres_port" {
  value = aws_db_instance.postgres.port
}

output "database_url_ssm_parameter" {
  value = aws_ssm_parameter.backend_database_url.name
}

output "dsn_ssm_parameter" {
  value = aws_ssm_parameter.backend_dsn.name
}
