# variables are mapped to locals for convenience of refactoring, maintenance, testing and dynamic mapping
locals {
  common_tags = {
    repository_name = "lambda-airly" # name of repository to easily identidy where to look for those resources' definitions
  }                                  # list of common tags for resources
  airly_api_key                     = var.airly_api_key
  airly_base_url                    = var.airly_base_url
  airly_max_distance                = var.airly_max_distance
  airly_measurements_nearest_method = var.airly_measurements_nearest_method
  airly_measurements_point_method   = var.airly_measurements_point_method
  airly_use_interpolation           = var.airly_use_interpolation
  aws_profile                       = var.aws_profile
  aws_region                        = var.aws_region
  enable_bucket_creation            = var.enable_bucket_creation
  enable_bucket_termination         = var.enable_bucket_termination
  function_description              = var.function_description
  function_dir                      = var.function_dir
  function_memory_limit             = var.function_memory_limit
  function_name                     = var.function_name
  function_runtime                  = var.function_runtime
  function_timeout                  = var.function_timeout
  log_retention                     = var.log_retention
  user_email                        = var.user_email
  user_locations                    = var.user_locations
  user_phone                        = var.user_phone
  s3_bucket                         = var.s3_bucket == "" ? "${local.aws_profile}-metadata" : var.s3_bucket                                    # set default value if s3_bucket is not defined
  s3_key                            = var.s3_key == "" ? "${local.common_tags.repository_name}/lambda/${local.function_name}.zip" : var.s3_key # set default value if s3_key is not defined
}

### DATA SOURCES - GET
# get account id from provided credentials
data "aws_caller_identity" "default" {}

# get default region name from provided credentials
data "aws_region" "default" {
  name = local.aws_region
}

# get properties of package on s3
# for obvious reasons package must be created beforehand
data "aws_s3_bucket_object" "package" {
  bucket = local.s3_bucket
  key    = local.s3_key

  depends_on = [
    aws_s3_bucket.metadata,
    null_resource.package,
  ]
}


### DATA SOURCES - SET
# set content of assume role policy for lambda
data "aws_iam_policy_document" "assume_role" {
  policy_id = "lambda-assume-role"

  statement {
    sid     = "LambdaAssumeRole"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

# set content of policy that will be attached to lambda role
data "aws_iam_policy_document" "airly" {
  policy_id = "lambda-function-policy"

  # allow writing logs in cloudwatch
  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:logs:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:log-group:/aws/lambda/${local.function_name}:*"
    ]
  }

  statement {
    sid     = "TopicPublish"
    actions = ["sns:Publish"]
    effect  = "Allow"
    resources = [
      "arn:aws:sns:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:${local.function_name}",
    ]
  }
}
