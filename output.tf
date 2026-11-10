output "eks_security_group_id" {
  value = aws_security_group.eks.id
}

data "aws_sqs_queue" "service_orders_created" {
  name = "services-ms-service-orders-created.fifo"
}

data "aws_sqs_queue" "service_order_status_changed" {
  name = "services-ms-service-order-status-changed.fifo"
}

output "sqs_service_orders_created_url" {
  description = "URL da fila FIFO de O.S. criadas (monólito -> MS)"
  value       = data.aws_sqs_queue.service_orders_created.url
}

output "sqs_service_order_status_changed_url" {
  description = "URL da fila FIFO de mudança de status (MS -> monólito)"
  value       = data.aws_sqs_queue.service_order_status_changed.url
}
