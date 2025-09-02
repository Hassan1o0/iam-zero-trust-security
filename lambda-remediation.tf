# Lambda function for S3 bucket remediation
resource "aws_lambda_function" "s3_remediation" {
  filename         = "s3_remediation.zip"
  function_name    = "${local.project_name}-s3-remediation"
  role            = aws_iam_role.lambda_service_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.config_bucket.bucket
    }
  }

  tags = local.tags
}

# Create the Lambda deployment package
data "archive_file" "s3_remediation_zip" {
  type        = "zip"
  output_path = "s3_remediation.zip"
  source {
    content = <<EOF
import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Auto-remediate S3 bucket public access violations
    """
    try:
        config = event['detail']
        resource_id = config['resourceId']
        compliance_type = config['newEvaluationResult']['complianceType']
        
        if compliance_type == 'NON_COMPLIANT':
            s3_client = boto3.client('s3')
            
            # Apply public access block
            s3_client.put_public_access_block(
                Bucket=resource_id,
                PublicAccessBlockConfiguration={
                    'BlockPublicAcls': True,
                    'IgnorePublicAcls': True,
                    'BlockPublicPolicy': True,
                    'RestrictPublicBuckets': True
                }
            )
            
            # Remove public read policy if exists
            try:
                s3_client.delete_bucket_policy(Bucket=resource_id)
            except:
                pass  # Policy might not exist
                
            logger.info(f"Remediated S3 bucket: {resource_id}")
            
            return {
                'statusCode': 200,
                'body': json.dumps(f'Successfully remediated {resource_id}')
            }
        else:
            logger.info(f"Resource {resource_id} is compliant, no action needed")
            return {
                'statusCode': 200,
                'body': json.dumps('No remediation needed')
            }
            
    except Exception as e:
        logger.error(f"Error in remediation: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
EOF
    filename = "index.py"
  }
}

# EventBridge rule for Config compliance changes
resource "aws_cloudwatch_event_rule" "config_compliance" {
  name        = "${local.project_name}-config-compliance"
  description = "Capture Config compliance changes"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      messageType = ["ComplianceChangeNotification"]
    }
  })

  tags = local.tags
}

# EventBridge target for Lambda
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.config_compliance.name
  target_id = "ConfigComplianceTarget"
  arn       = aws_lambda_function.s3_remediation.arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.config_compliance.arn
}

# SNS topic for notifications
resource "aws_sns_topic" "compliance_alerts" {
  name = "${local.project_name}-compliance-alerts"

  tags = local.tags
}

# Lambda function for SNS notifications
resource "aws_lambda_function" "sns_notifier" {
  filename         = "sns_notifier.zip"
  function_name    = "${local.project_name}-sns-notifier"
  role            = aws_iam_role.lambda_service_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.compliance_alerts.arn
    }
  }

  tags = local.tags
}

# Create the SNS notifier deployment package
data "archive_file" "sns_notifier_zip" {
  type        = "zip"
  output_path = "sns_notifier.zip"
  source {
    content = <<EOF
import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Send SNS notification for compliance violations
    """
    try:
        sns_client = boto3.client('sns')
        
        config = event['detail']
        resource_id = config['resourceId']
        rule_name = config['configRuleName']
        compliance_type = config['newEvaluationResult']['complianceType']
        
        if compliance_type == 'NON_COMPLIANT':
            message = f"""
            AWS Config Compliance Violation Detected!
            
            Resource: {resource_id}
            Rule: {rule_name}
            Status: NON_COMPLIANT
            Time: {config['newEvaluationResult']['resultRecordedTime']}
            
            Auto-remediation has been triggered.
            """
            
            sns_client.publish(
                TopicArn=context.environment['SNS_TOPIC_ARN'],
                Subject=f"Compliance Violation: {rule_name}",
                Message=message
            )
            
            logger.info(f"Sent notification for {resource_id}")
            
        return {
            'statusCode': 200,
            'body': json.dumps('Notification sent successfully')
        }
        
    except Exception as e:
        logger.error(f"Error sending notification: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
EOF
    filename = "index.py"
  }
}

# EventBridge target for SNS notifier
resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.config_compliance.name
  target_id = "SNSNotificationTarget"
  arn       = aws_lambda_function.sns_notifier.arn
}

# Lambda permission for SNS notifier
resource "aws_lambda_permission" "allow_sns_eventbridge" {
  statement_id  = "AllowSNSExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sns_notifier.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.config_compliance.arn
}
