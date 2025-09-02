output "config_bucket_name" {
  value       = aws_s3_bucket.config_bucket.bucket
  description = "S3 bucket name for AWS Config"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.compliance_alerts.arn
  description = "SNS topic ARN for compliance alerts"
}

output "admin_users" {
  value       = [for user in aws_iam_user.admin_users : user.name]
  description = "List of admin user names"
}

output "developer_users" {
  value       = [for user in aws_iam_user.developer_users : user.name]
  description = "List of developer user names"
}

output "readonly_users" {
  value       = [for user in aws_iam_user.readonly_users : user.name]
  description = "List of readonly user names"
}

output "cross_account_role_arn" {
  value       = aws_iam_role.cross_account_role.arn
  description = "Cross-account role ARN"
}

output "lambda_remediation_function_name" {
  value       = aws_lambda_function.s3_remediation.function_name
  description = "Lambda function name for S3 remediation"
}
