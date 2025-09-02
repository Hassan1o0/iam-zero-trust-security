# Cross-account role for external access
resource "aws_iam_role" "cross_account_role" {
  name = "${local.project_name}-cross-account-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:root"  # Replace with actual external account ID
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "unique-external-id-12345"  # Replace with actual external ID
          }
          IpAddress = {
            "aws:SourceIp" = var.corporate_ip_range
          }
        }
      }
    ]
  })

  tags = local.tags
}

# Policy for cross-account role
data "aws_iam_policy_document" "cross_account_policy" {
  statement {
    sid    = "AllowLimitedAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents"
    ]
    resources = [
      "arn:aws:s3:::${local.project_name}-shared-*",
      "arn:aws:s3:::${local.project_name}-shared-*/*",
      "arn:aws:logs:*:*:log-group:/aws/lambda/${local.project_name}-*"
    ]
  }
}

resource "aws_iam_policy" "cross_account_policy" {
  name        = "${local.project_name}-cross-account-policy"
  description = "Limited access policy for cross-account role"
  policy      = data.aws_iam_policy_document.cross_account_policy.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "cross_account_policy" {
  role       = aws_iam_role.cross_account_role.name
  policy_arn = aws_iam_policy.cross_account_policy.arn
}

# Service role for Lambda functions
resource "aws_iam_role" "lambda_service_role" {
  name = "${local.project_name}-lambda-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Additional permissions for Lambda remediation
data "aws_iam_policy_document" "lambda_remediation_policy" {
  statement {
    sid    = "AllowConfigRemediation"
    effect = "Allow"
    actions = [
      "config:PutEvaluations",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketAcl",
      "s3:PutBucketPolicy",
      "ec2:ModifyInstanceAttribute",
      "ec2:StopInstances",
      "ec2:TerminateInstances"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_remediation_policy" {
  name        = "${local.project_name}-lambda-remediation-policy"
  description = "Policy for Lambda remediation functions"
  policy      = data.aws_iam_policy_document.lambda_remediation_policy.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "lambda_remediation" {
  role       = aws_iam_role.lambda_service_role.name
  policy_arn = aws_iam_policy.lambda_remediation_policy.arn
}
