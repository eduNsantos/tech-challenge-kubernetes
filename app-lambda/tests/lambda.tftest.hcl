mock_provider "aws" {
  mock_data "aws_db_instance" {
    defaults = {
      address = "app.rds.test"
      port    = 3306
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/test"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      arn = "arn:aws:lambda:us-east-1:123456789012:function:test"
    }
  }

  mock_resource "aws_cloudwatch_event_rule" {
    defaults = {
      arn = "arn:aws:events:us-east-1:123456789012:rule/test"
    }
  }
}

override_data {
  target = data.aws_sqs_queue.services_ms["service_orders_created"]
  values = {
    arn = "arn:aws:sqs:us-east-1:123456789012:created.fifo"
    url = "https://sqs.test/created.fifo"
  }
}

override_data {
  target = data.aws_sqs_queue.services_ms["service_order_status_changed"]
  values = {
    arn = "arn:aws:sqs:us-east-1:123456789012:status.fifo"
    url = "https://sqs.test/status.fifo"
  }
}

override_data {
  target = data.aws_sqs_queue.services_ms["service_order_execution"]
  values = {
    arn = "arn:aws:sqs:us-east-1:123456789012:execution.fifo"
    url = "https://sqs.test/execution.fifo"
  }
}

override_data {
  target = data.archive_file.lambda
  values = {
    output_path         = "build/application-lambda.zip"
    output_base64sha256 = "dGVzdA=="
  }
}

variables {
  db_password = "test-only-password"
  app_key     = "base64:dGVzdA=="
}

run "workers_scoped_to_their_queues" {
  command = apply

  assert {
    condition = (
      aws_lambda_function.worker["execution-consumer"].handler == "App\\Lambda\\ServiceOrderExecutionHandler" &&
      aws_lambda_function.worker["outbox-publisher"].handler == "App\\Lambda\\PublishOutboxHandler" &&
      alltrue([for fn in aws_lambda_function.worker : fn.runtime == "provided.al2023" && fn.timeout <= 60]) &&
      aws_lambda_function.worker["execution-consumer"].environment[0].variables.SERVICES_MS_ENABLED == "true"
    )
    error_message = "Cada worker deve ter sua Lambda Bref, com timeout dentro do visibility timeout das filas (60s)."
  }

  assert {
    condition = (
      aws_lambda_event_source_mapping.execution.event_source_arn == "arn:aws:sqs:us-east-1:123456789012:execution.fifo" &&
      contains(aws_lambda_event_source_mapping.execution.function_response_types, "ReportBatchItemFailures")
    )
    error_message = "O consumer deve ser acionado pela fila de execução e reportar falhas por mensagem."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.lambda_sqs["execution-consumer"].policy).Statement[0].Resource == "arn:aws:sqs:us-east-1:123456789012:execution.fifo" &&
      !contains(jsondecode(aws_iam_role_policy.lambda_sqs["execution-consumer"].policy).Statement[0].Action, "sqs:SendMessage") &&
      jsondecode(aws_iam_role_policy.lambda_sqs["outbox-publisher"].policy).Statement[0].Action == ["sqs:SendMessage"] &&
      toset(jsondecode(aws_iam_role_policy.lambda_sqs["outbox-publisher"].policy).Statement[0].Resource) == toset([
        "arn:aws:sqs:us-east-1:123456789012:created.fifo",
        "arn:aws:sqs:us-east-1:123456789012:status.fifo",
      ])
    )
    error_message = "As roles das Lambdas devem ter acesso mínimo às suas filas."
  }

  assert {
    condition     = aws_cloudwatch_event_rule.outbox_publisher.schedule_expression == "rate(1 minute)"
    error_message = "O publisher da outbox deve ser agendado a cada minuto."
  }
}
