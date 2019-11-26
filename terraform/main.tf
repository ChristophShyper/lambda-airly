# use local backend, store tfstate on disk, just to simplify example
terraform {
  required_version = "~> 0.12"

  required_providers {
    aws  = "~> 2.33"
    null = "~> 2.1"
  }
}

# AWS provided details used
# access_key and secret_key, or shared_credentials_file and profile
provider "aws" {
  access_key              = local.use_aws_keys ? local.aws_access_key : null
  profile                 = local.use_aws_credentials_file ? local.aws_profile : null
  region                  = local.aws_region
  secret_key              = local.use_aws_keys ? local.aws_secret_key : null
  shared_credentials_file = local.use_aws_credentials_file ? local.aws_credentials_file : null
}

# define Log Group for Lambda, so it can be deleted when stack is destroy
resource "aws_cloudwatch_log_group" "airly" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = local.log_retention

  tags = merge({ terraform_resource = "aws_cloudwatch_log_group.airly", terraform_count = "" }, local.common_tags)
}

# S3 bucket where package will be placed
# TODO: CAUTION - will be created only if enable_bucket_creation is true
# TODO: CAUTION - will be destroyed only if enable_bucket_creation and enable_bucket_termination are true, even when bucket is not empty
resource "aws_s3_bucket" "metadata" {
  count = local.enable_bucket_creation ? 1 : 0

  acl           = "private"
  bucket        = local.s3_bucket
  force_destroy = local.enable_bucket_termination ? true : false

  tags = merge({ terraform_resource = "aws_s3_bucket.metadata", terraform_count = count.index }, local.common_tags)
}

# creates deployment package for lambda
# will be triggered anytime files in function_dir directory change
# for obious reasons bucket exists beforehand
resource "null_resource" "package" {
  triggers = {
    files_hash = base64sha256(join("", [for source_file in fileset("../${local.function_dir}", "*") : filesha256("../${local.function_dir}/${source_file}")]))
  }

  provisioner "local-exec" {
    command     = "./lambda.sh deploy ${local.function_name} ${local.function_runtime} ${local.aws_profile} ${local.s3_bucket} ${local.s3_key}"
    working_dir = "../${local.function_dir}"
  }

  depends_on = [
    aws_s3_bucket.metadata,
  ]
}

# IAM role used by lambda
resource "aws_iam_role" "airly" {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = "Role for ${local.function_name} Lambda"
  name               = "${local.function_name}-role"

  tags = merge({ terraform_resource = "aws_iam_role.airly", terraform_count = "" }, local.common_tags)
}

# attach IAM policy to the IAM role used by Lambda
resource "aws_iam_role_policy" "airly" {
  name   = "${local.function_name}-policy"
  policy = data.aws_iam_policy_document.airly.json
  role   = aws_iam_role.airly.id
}

# main Lambda function definition
# update will be trigger only when filebase64sha256 tag on package object changes
# for obvious reasons role and package must exist beforehand
resource "aws_lambda_function" "airly" {
  description      = local.function_description
  function_name    = local.function_name
  handler          = "index.handler"
  memory_size      = local.function_memory_limit
  role             = aws_iam_role.airly.arn
  runtime          = local.function_runtime
  s3_bucket        = local.s3_bucket
  s3_key           = local.s3_key
  source_code_hash = data.aws_s3_bucket_object.package.tags.filebase64sha256
  timeout          = local.function_timeout

  environment {
    variables = {
      API_KEY              = local.airly_api_key
      BASE_URL             = local.airly_base_url
      MAX_DISTANCE         = local.airly_max_distance
      MEASUREMENTS_NEAREST = local.airly_measurements_nearest_method
      MEASUREMENTS_POINT   = local.airly_measurements_point_method
      SNS_TOPIC            = aws_sns_topic.airly.arn
      USE_INTERPOLATION    = local.airly_use_interpolation
    }
  }

  depends_on = [
    aws_iam_role.airly,
    null_resource.package,
    aws_sns_topic.airly,
  ]

  tags = merge({ terraform_resource = "aws_lambda_function.airly", terraform_count = "" }, local.common_tags)
}

resource "aws_sns_topic" "airly" {
  display_name = title(replace(local.function_name, "-", " "))
  name         = local.function_name

  tags = merge({ terraform_resource = "aws_sns_topic.airly", terraform_count = "" }, local.common_tags)
}

resource "aws_sns_topic_subscription" "phone" {
  count = local.user_phone != "" ? 1 : 0

  endpoint  = local.user_phone
  protocol  = "sms"
  topic_arn = aws_sns_topic.airly.arn

  depends_on = [aws_sns_topic.airly]
}

resource "aws_cloudformation_stack" "email" {
  count = local.user_email != "" ? 1 : 0

  name          = ""
  template_body = file("cloudformation.email.subscribe.yml")
  parameters = {
    EmailAddress = local.user_email
    TopicArn     = aws_sns_topic.airly.arn
  }

  depends_on = [aws_sns_topic.airly]

  tags = merge({ terraform_resource = "aws_cloudformation_stack.email", terraform_count = count.index }, local.common_tags)
}

# cw event rule to trigger lambda periodically
resource "aws_cloudwatch_event_rule" "event" {
  count = length(local.user_locations)

  name                = "${local.function_name}-${local.user_locations[count.index]["name"]}-${replace(replace(split("/", local.user_locations[count.index]["map_point"])[length(split("/", local.user_locations[count.index]["map_point"])) - 1], "#", ""), ",", "-")}"
  description         = "Triggers ${local.function_name} Lambda using expression ${local.user_locations[count.index]["expression"]} for ${local.user_locations[count.index]["name"]} at ${replace(replace(split("/", local.user_locations[count.index]["map_point"])[length(split("/", local.user_locations[count.index]["map_point"])) - 1], "#", ""), ",", " and ")}."
  schedule_expression = local.user_locations[count.index]["expression"]

  tags = merge({ terraform_resource = "aws_cloudwatch_event_rule.event", terraform_count = count.index }, local.common_tags)
}

# permision for lambda to be invoked by cw event
resource "aws_lambda_permission" "event" {
  count = length(local.user_locations)

  action        = "lambda:InvokeFunction"
  function_name = local.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event[count.index].arn
  statement_id  = "EventInvokeFor${local.user_locations[count.index]["name"]}"
}
