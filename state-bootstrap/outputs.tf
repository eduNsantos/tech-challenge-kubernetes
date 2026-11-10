output "state_bucket_name" {
  description = "S3 bucket name for the EKS Terraform backend."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "eks_state_key" {
  description = "S3 object key to configure in the EKS Terraform backend."
  value       = "eks/terraform.tfstate"
}
