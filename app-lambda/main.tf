# Consumer e publisher da aplicação rodando em Lambda (PHP 8.4 via Bref 3).
#
# O código vem da mesma imagem GHCR implantada no EKS: o workflow deploy-eks.yml
# roda scripts/build-lambda.sh dentro da imagem e gera build/lambda antes do plan.
# As Lambdas rodam fora da VPC: o RDS da aplicação é público (laboratório) e o
# SG "rds" libera a 3306; assim o publisher alcança o SQS sem NAT nem VPC endpoint.
# As filas pertencem ao tech-challenge-services-ms e são só consultadas aqui.

data "aws_db_instance" "app" {
  db_instance_identifier = var.db_identifier
}

data "aws_sqs_queue" "services_ms" {
  for_each = {
    service_orders_created       = "service-orders-created"
    service_order_status_changed = "service-order-status-changed"
    service_order_execution      = "service-order-execution"
  }

  name = "${var.services_ms_queue_prefix}-${each.value}.fifo"
}

locals {
  bref_php_layer_arn = "arn:aws:lambda:${var.aws_region}:873528684822:layer:php-84:${var.bref_php_layer_version}"

  # Mesma configuração do ConfigMap app-config do EKS, sem o que só a API usa.
  lambda_environment = {
    APP_NAME                  = "POS Tech"
    APP_ENV                   = "production"
    APP_DEBUG                 = "false"
    APP_KEY                   = var.app_key
    APP_LOCALE                = "pt_BR"
    LOG_CHANNEL               = "stderr"
    BREF_LARAVEL_OMIT_INITLOG = "1"
    DB_CONNECTION             = "mysql"
    DB_HOST                   = data.aws_db_instance.app.address
    DB_PORT                   = tostring(data.aws_db_instance.app.port)
    DB_DATABASE               = var.db_name
    DB_USERNAME               = var.db_username
    DB_PASSWORD               = var.db_password
    QUEUE_CONNECTION          = "database"
    CACHE_STORE               = "database"
    MAIL_MAILER               = "log"
    NEW_RELIC_ENABLED         = "false"
    # O consumer grava a mudança para "finalizada" na outbox; precisa da integração ligada.
    SERVICES_MS_ENABLED                  = "true"
    SQS_SERVICE_ORDERS_CREATED_URL       = data.aws_sqs_queue.services_ms["service_orders_created"].url
    SQS_SERVICE_ORDER_STATUS_CHANGED_URL = data.aws_sqs_queue.services_ms["service_order_status_changed"].url
    SQS_SERVICE_ORDER_EXECUTION_URL      = data.aws_sqs_queue.services_ms["service_order_execution"].url
  }

  lambda_functions = {
    # Services MS -> aplicação: início/fim de execução.
    execution-consumer = {
      handler = "App\\Lambda\\ServiceOrderExecutionHandler"
      timeout = 30
      statements = [{
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
        ]
        Resource = data.aws_sqs_queue.services_ms["service_order_execution"].arn
      }]
    }
    # Aplicação -> Services MS: outbox de criação, aprovação e status, agendado a cada minuto.
    outbox-publisher = {
      handler = "App\\Lambda\\PublishOutboxHandler"
      timeout = 60
      statements = [{
        Effect = "Allow"
        Action = ["sqs:SendMessage"]
        Resource = [
          data.aws_sqs_queue.services_ms["service_orders_created"].arn,
          data.aws_sqs_queue.services_ms["service_order_status_changed"].arn,
        ]
      }]
    }
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../build/lambda"
  output_path = "${path.module}/../build/application-lambda.zip"
}

resource "aws_iam_role" "lambda" {
  for_each = local.lambda_functions

  name = "${var.project_name}-${each.key}-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  for_each = local.lambda_functions

  role       = aws_iam_role.lambda[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_sqs" {
  for_each = local.lambda_functions

  name = "${var.project_name}-${each.key}-sqs"
  role = aws_iam_role.lambda[each.key].id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = each.value.statements
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = local.lambda_functions

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = 14
}

resource "aws_lambda_function" "worker" {
  for_each = local.lambda_functions

  function_name    = "${var.project_name}-${each.key}"
  role             = aws_iam_role.lambda[each.key].arn
  runtime          = "provided.al2023"
  layers           = [local.bref_php_layer_arn]
  handler          = each.value.handler
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = each.value.timeout
  memory_size      = 512

  environment {
    variables = local.lambda_environment
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy.lambda_sqs,
  ]
}

# Consumer: o event source mapping faz o polling e apaga as mensagens processadas.
# Falhas voltam via batchItemFailures e seguem o redrive da fila (3 tentativas -> DLQ).
resource "aws_lambda_event_source_mapping" "execution" {
  event_source_arn        = data.aws_sqs_queue.services_ms["service_order_execution"].arn
  function_name           = aws_lambda_function.worker["execution-consumer"].arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]

  # A conta tem limite de 10 execuções concorrentes: sem reserved concurrency,
  # o teto fica no mapping. Em FIFO, a ordem por MessageGroupId é preservada.
  scaling_config {
    maximum_concurrency = 2
  }
}

# Publisher: o EventBridge invoca a cada minuto; a invocação publica em ciclos
# até perto do timeout. Um lock no MySQL impede publishers concorrentes.
resource "aws_cloudwatch_event_rule" "outbox_publisher" {
  name                = "${var.project_name}-outbox-publisher"
  description         = "Publica a outbox da aplicacao nas filas do Services MS"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "outbox_publisher" {
  rule = aws_cloudwatch_event_rule.outbox_publisher.name
  arn  = aws_lambda_function.worker["outbox-publisher"].arn

  retry_policy {
    maximum_retry_attempts       = 0
    maximum_event_age_in_seconds = 60
  }
}

resource "aws_lambda_permission" "outbox_publisher_schedule" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.worker["outbox-publisher"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.outbox_publisher.arn
}

# A próxima execução agendada já tenta de novo; retries assíncronos só sobreporiam invocações.
resource "aws_lambda_function_event_invoke_config" "outbox_publisher" {
  function_name                = aws_lambda_function.worker["outbox-publisher"].function_name
  maximum_retry_attempts       = 0
  maximum_event_age_in_seconds = 60
}
