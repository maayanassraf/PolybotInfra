resource "aws_s3_bucket" "tf-images-bucket" {
  count = length(var.env)
  bucket = "tf-maayana-images-bucket-${var.env[count.index]}"
  tags = {
    Name        = "tf-maayana-images-bucket-${var.env[count.index]}"
    Env         = var.env[count.index]
    Terraform   = true
  }
  force_destroy = true
}

resource "aws_dynamodb_table" "tf-predictions-dynamodb-table" {
  count = length(var.env)
  name           = "tf-maayana-predictions-dynamodb-table-${var.env[count.index]}"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "prediction_id"

  attribute {
    name = "prediction_id"
    type = "S"
  }
}

resource "aws_sqs_queue" "tf-project-queue" {
  count = length(var.env)
  name                      = "tf-maayana-project-queue-${var.env[count.index]}"
  message_retention_seconds = 86400
  sqs_managed_sse_enabled = true

  tags = {
    Environment = var.env[count.index]
  }
}

resource "aws_secretsmanager_secret" "tf-botToken" {
  count = length(var.env)
  name = "tf-telegram-botToken-${var.env[count.index]}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "tf-botToken-value" {
  count = length(var.env)
  secret_id     = aws_secretsmanager_secret.tf-botToken[count.index].id
  secret_string = var.env[count.index] == "dev" ? var.botTokenDev : var.botTokenProd
}