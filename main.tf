resource "sumologic_http_source" "http_source" {
  name = var.name
  description = "${var.description} - HTTP Source for CloudWatch Logs"
  category = var.category
  collector_id = var.collector_id
}

data "aws_iam_policy_document" "lambda_assume_role_document" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy_document" "lambda_execution_role" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
      "sqs:ListQueues",
      "sqs:ChangeMessageVisibility",
      "sqs:SendMessageBatch",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:ListQueueTags",
      "sqs:ListDeadLetterSourceQueues",
      "sqs:DeleteMessageBatch",
      "sqs:PurgeQueue",
      "sqs:DeleteQueue",
      "sqs:CreateQueue",
      "sqs:ChangeMessageVisibilityBatch",
      "sqs:SetQueueAttributes"
    ]
    resources = [
      aws_sqs_queue.deadletter_queue.arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/*"
    ]
  }
}

resource "aws_lambda_permission" "allow_cloudwatch_events" {
  statement_id = "AllowExecutionFromCloudWatchEvents"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sumologic_dlq_lambda.function_name
  principal = "events.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_lambda_permission" "allow_cloudwatch_logs" {
  statement_id = "AllowExecutionFromCloudWatchLogs"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sumologic_dlq_lambda.function_name
  principal = "logs.ap-southeast-2.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_iam_role" "lambda_role" {
  name = "sumologic-lambda-execution-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_document.json
}

resource "aws_iam_role_policy" "lambda_role_policy_attachment" {
  role = aws_iam_role.lambda_role.name
  policy = data.aws_iam_policy_document.lambda_execution_role.json
}

resource "aws_lambda_function" "sumologic_dlq_lambda" {
  function_name = "sumologic-dql-lambda"
  s3_bucket = "appdevzipfiles-ap-southeast-2"
  s3_key = "cloudwatchlogs-with-dlq.zip"
  handler = "cloudwatchlogs_lambda.handler"

  role = aws_iam_role.lambda_role.arn
  memory_size = 128
  runtime = "nodejs10.x"
  timeout = 300

  environment {
    variables = {
      TASK_QUEUE_URL = aws_sqs_queue.deadletter_queue.id
      NUM_OF_WORKERS = 4
      SUMO_ENDPOINT = sumologic_http_source.http_source.url
      LOG_FORMAT = var.log_format
      INCLUDE_LOG_INFO = var.include_log_info
      LOG_STREAM_PREFIX = var.log_stream_prefix
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.deadletter_queue.arn
  }
}

resource "aws_lambda_function" "sumologic_logs_lambda" {
  function_name = "sumologic-cloudwatch-logs-lambda"
  s3_bucket = "appdevzipfiles-ap-southeast-2"
  s3_key = "cloudwatchlogs-with-dlq.zip"
  handler = "DLQProcessor.handler"

  role = aws_iam_role.lambda_role.arn
  memory_size = 128
  runtime = "nodejs10.x"
  timeout = 300

  environment {
    variables = {
      TASK_QUEUE_URL = aws_sqs_queue.deadletter_queue.id
      SUMO_ENDPOINT = sumologic_http_source.http_source.url
      LOG_FORMAT = var.log_format
      INCLUDE_LOG_INFO = var.include_log_info
      LOG_STREAM_PREFIX = var.log_stream_prefix
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.deadletter_queue.arn
  }
}

resource "aws_sqs_queue" "deadletter_queue" {
  name = "sumologic-deadletter-queue"
  delay_seconds = 90
  max_message_size = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
}

resource "aws_cloudwatch_log_group" "cloudwatch_log_group" {
  name = "sumologic/cloudwatch-log-subscriptions"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_subscription_filter" "cloudwatch_lambda_log_subscriptions" {
  name = "sumologic-cloudwatch-logs-filter"
  log_group_name = aws_cloudwatch_log_group.cloudwatch_log_group.name
  filter_pattern = ""
  destination_arn = aws_lambda_function.sumologic_dlq_lambda.arn
}

resource "aws_cloudwatch_event_rule" "cloudwatch_event_rule" {
  name = "sumologic-cloudwatch-event-rule"
  description = "Sumologic Cloudwatch Events Cron rule"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "sns" {
  rule = aws_cloudwatch_event_rule.cloudwatch_event_rule.name
  target_id = aws_lambda_function.sumologic_dlq_lambda.function_name
  arn = aws_lambda_function.sumologic_dlq_lambda.arn
}

resource "aws_cloudwatch_log_subscription_filter" "cloudwatch_lambda_log_custom_subscriptions" {
  for_each = var.log_groups

  name = "sumologic-cloudwatch-logs-filter"
  log_group_name = each.key
  filter_pattern = each.value["filter_pattern"]
  destination_arn = aws_lambda_function.sumologic_dlq_lambda.arn
}
