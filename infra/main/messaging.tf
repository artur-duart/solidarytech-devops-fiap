resource "aws_sqs_queue" "donation_events_dlq" {
  name                      = "${local.name}-donation-events-dlq"
  sqs_managed_sse_enabled   = true
  message_retention_seconds = 1209600

  tags = {
    Service = "donation-service"
  }
}

resource "aws_sqs_queue" "donation_events" {
  name                    = "${local.name}-donation-events"
  sqs_managed_sse_enabled = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.donation_events_dlq.arn
    maxReceiveCount     = 5
  })

  tags = {
    Service = "donation-service"
  }
}

resource "aws_dynamodb_table" "volunteers" {
  name         = "SolidaryTechVolunteers"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "volunteer_id"

  attribute {
    name = "volunteer_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Service = "volunteer-service"
  }
}
