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
}
