# S3 bucket for Config
resource "aws_s3_bucket" "config_bucket" {
  bucket = "${local.project_name}-config-${random_id.bucket_suffix.hex}"

  tags = local.tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "config_bucket" {
  bucket = aws_s3_bucket.config_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_bucket" {
  bucket = aws_s3_bucket.config_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "config_bucket" {
  bucket = aws_s3_bucket.config_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM role for Config
resource "aws_iam_role" "config_role" {
  name = "${local.project_name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "config_role" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# Additional policy for Config to access S3
data "aws_iam_policy_document" "config_s3_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketAcl",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.config_bucket.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = ["${aws_s3_bucket.config_bucket.arn}/*"]
  }
}

resource "aws_iam_policy" "config_s3_policy" {
  name        = "${local.project_name}-config-s3-policy"
  description = "Policy for Config to access S3 bucket"
  policy      = data.aws_iam_policy_document.config_s3_policy.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "config_s3_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = aws_iam_policy.config_s3_policy.arn
}

# Config Configuration Recorder
resource "aws_config_configuration_recorder" "main" {
  name     = "${local.project_name}-config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  depends_on = [aws_config_delivery_channel.main]
}

# Config Delivery Channel
resource "aws_config_delivery_channel" "main" {
  name           = "${local.project_name}-config-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config_bucket.bucket
}

# Config Rules
resource "aws_config_config_rule" "s3_bucket_public_read_prohibited" {
  name = "${local.project_name}-s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "s3_bucket_public_write_prohibited" {
  name = "${local.project_name}-s3-bucket-public-write-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "s3_bucket_ssl_requests_only" {
  name = "${local.project_name}-s3-bucket-ssl-requests-only"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SSL_REQUESTS_ONLY"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "ec2_instances_in_vpc" {
  name = "${local.project_name}-ec2-instances-in-vpc"

  source {
    owner             = "AWS"
    source_identifier = "INSTANCES_IN_VPC"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "root_hardware_mfa_enabled" {
  name = "${local.project_name}-root-hardware-mfa-enabled"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_HARDWARE_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "iam_password_policy" {
  name = "${local.project_name}-iam-password-policy"

  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
  }

  input_parameters = jsonencode({
    RequireUppercaseCharacters = true
    RequireLowercaseCharacters = true
    RequireSymbols             = true
    RequireNumbers             = true
    MinimumPasswordLength      = 14
    PasswordReusePrevention    = 24
    MaxPasswordAge             = 90
  })

  depends_on = [aws_config_configuration_recorder.main]
}
