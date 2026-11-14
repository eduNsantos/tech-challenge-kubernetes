variable "aws_region" {
  description = "AWS region where the Terraform state bucket is created."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for the shared Terraform states."
  type        = string
  default     = "techchallenge-tfstate-477478162709-eks"
}
