output "state_bucket_name" {
  description = "S3 bucket name for the shared Terraform backends."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "eks_state_key" {
  description = "S3 object key to configure in the EKS Terraform backend."
  value       = "eks/terraform.tfstate"
}

output "repository_state_keys" {
  description = "Distinct S3 object keys for each repository's Terraform backend."
  value = {
    kubernetes       = "eks/terraform.tfstate"
    services_ms      = "services-ms/terraform.tfstate"
    database         = "database/terraform.tfstate"
    lambda_functions = "lambda-functions/terraform.tfstate"
    application      = "application/terraform.tfstate"
  }
}
