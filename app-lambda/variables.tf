variable "aws_region" {
  description = "Região da AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo dos recursos"
  type        = string
  default     = "postech"
}

variable "db_identifier" {
  description = "Identificador do RDS da aplicação (tech-challenge-database)"
  type        = string
  default     = "techchallenge-rds"
}

variable "db_name" {
  description = "Banco de dados da aplicação"
  type        = string
  default     = "techchallenge"
}

variable "db_username" {
  description = "Usuário do banco de dados"
  type        = string
  default     = "root"
}

variable "db_password" {
  description = "Senha do banco de dados"
  type        = string
  sensitive   = true
}

variable "app_key" {
  description = "APP_KEY do Laravel (a mesma do deploy no EKS)"
  type        = string
  sensitive   = true
}

variable "services_ms_queue_prefix" {
  description = "Prefixo das filas FIFO criadas pelo tech-challenge-services-ms"
  type        = string
  default     = "services-ms"
}

variable "bref_php_layer_version" {
  description = "Versão da layer php-84 do Bref 3 na região (ver vendor/bref/bref/layers.json)"
  type        = number
  default     = 25
}
