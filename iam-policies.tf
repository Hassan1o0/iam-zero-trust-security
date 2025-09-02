# MFA Enforcement Policy
data "aws_iam_policy_document" "mfa_enforcement" {
  statement {
    sid    = "DenyAllExceptListedIfNoMFA"
    effect = "Deny"
    not_actions = [
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:GetUser",
      "iam:ListMFADevices",
      "iam:ListVirtualMFADevices",
      "iam:ResyncMFADevice",
      "sts:GetSessionToken"
    ]
    resources = ["*"]
    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}

resource "aws_iam_policy" "mfa_enforcement" {
  name        = "${local.project_name}-mfa-enforcement"
  description = "Enforces MFA for all actions except MFA setup"
  policy      = data.aws_iam_policy_document.mfa_enforcement.json

  tags = local.tags
}

# Admin Policy with IP restrictions
data "aws_iam_policy_document" "admin_policy" {
  statement {
    sid    = "AllowAllForAdmins"
    effect = "Allow"
    actions = ["*"]
    resources = ["*"]
    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = [var.corporate_ip_range]
    }
  }
}

resource "aws_iam_policy" "admin_policy" {
  name        = "${local.project_name}-admin-policy"
  description = "Admin policy with IP restrictions"
  policy      = data.aws_iam_policy_document.admin_policy.json

  tags = local.tags
}

# Developer Policy - Limited permissions
data "aws_iam_policy_document" "developer_policy" {
  statement {
    sid    = "AllowEC2FullAccess"
    effect = "Allow"
    actions = [
      "ec2:*",
      "ec2-instance-connect:*"
    ]
    resources = ["*"]
    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = [var.corporate_ip_range]
    }
  }

  statement {
    sid    = "AllowS3LimitedAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${local.project_name}-dev-*",
      "arn:aws:s3:::${local.project_name}-dev-*/*"
    ]
    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = [var.corporate_ip_range]
    }
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = [var.corporate_ip_range]
    }
  }
}

resource "aws_iam_policy" "developer_policy" {
  name        = "${local.project_name}-developer-policy"
  description = "Developer policy with limited permissions and IP restrictions"
  policy      = data.aws_iam_policy_document.developer_policy.json

  tags = local.tags
}

# Read-only Policy
data "aws_iam_policy_document" "readonly_policy" {
  statement {
    sid    = "AllowReadOnlyAccess"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "s3:GetObject",
      "s3:ListBucket",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "iam:GetUser",
      "iam:ListAttachedUserPolicies",
      "iam:ListUserPolicies"
    ]
    resources = ["*"]
    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = [var.corporate_ip_range]
    }
  }
}

resource "aws_iam_policy" "readonly_policy" {
  name        = "${local.project_name}-readonly-policy"
  description = "Read-only policy with IP restrictions"
  policy      = data.aws_iam_policy_document.readonly_policy.json

  tags = local.tags
}

# Attach policies to groups
resource "aws_iam_group_policy_attachment" "admin_mfa" {
  group      = aws_iam_group.admins.name
  policy_arn = aws_iam_policy.mfa_enforcement.arn
}

resource "aws_iam_group_policy_attachment" "admin_policy" {
  group      = aws_iam_group.admins.name
  policy_arn = aws_iam_policy.admin_policy.arn
}

resource "aws_iam_group_policy_attachment" "developer_mfa" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.mfa_enforcement.arn
}

resource "aws_iam_group_policy_attachment" "developer_policy" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.developer_policy.arn
}

resource "aws_iam_group_policy_attachment" "readonly_mfa" {
  group      = aws_iam_group.readonly.name
  policy_arn = aws_iam_policy.mfa_enforcement.arn
}

resource "aws_iam_group_policy_attachment" "readonly_policy" {
  group      = aws_iam_group.readonly.name
  policy_arn = aws_iam_policy.readonly_policy.arn
}
