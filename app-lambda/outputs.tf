output "lambda_function_names" {
  description = "Lambdas do consumer e do publisher da aplicação"
  value       = { for k, fn in aws_lambda_function.worker : k => fn.function_name }
}
