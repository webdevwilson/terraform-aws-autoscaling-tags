locals {
  lambda_archive         = "${join("/", list(path.module, "lambda.zip"))}"
  autoscaling_group_name = "${element(split("/", var.autoscaling_group_arn), 1)}"
  name                   = "${local.autoscaling_group_name}_tags"
}

// Create a topic for this lambda
resource "aws_sns_topic" "main" {
  name = "${local.name}"
}

// Create the role that will be assigned to the lambda
resource "aws_iam_role" "main_lambda" {
  name_prefix = "${local.name}_lambda_"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

// Prevent logs from piling up
resource "aws_cloudwatch_log_group" "main" {
  name              = "/aws/lambda/${aws_lambda_function.main.function_name}"
  retention_in_days = 7
}

// Attach the default managed AWS policy for lambdas
resource "aws_iam_role_policy_attachment" "main_lambda" {
  role       = "${aws_iam_role.main_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}

// Defines the custom policy for the lambda
data "aws_iam_policy_document" "main_lambda" {
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:CompleteLifecycleAction",
      "autoscaling:CreateOrUpdateTags",
      "autoscaling:DescribeAutoScalingGroups",
    ]
    resources = ["${var.autoscaling_group_arn}"]
  }

  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "ec2:CreateTags",
    ]
    resources = ["*"]
  }
}

// Attach the custom policy for the lambda
resource "aws_iam_role_policy" "main_lambda" {
  name_prefix = "${local.name}_"
  role        = "${aws_iam_role.main_lambda.name}"
  policy      = "${data.aws_iam_policy_document.main_lambda.json}"
}

resource "aws_lambda_function" "main" {
  function_name    = "${local.name}"
  description      = "Adds tags to autoscaling groups"
  filename         = "${local.lambda_archive}"
  source_code_hash = "${base64sha256(file(local.lambda_archive))}"
  role             = "${aws_iam_role.main_lambda.arn}"
  runtime          = "python2.7"
  handler          = "lambda.handler"
  publish          = "true"
  tags             = "${var.tags}"
  timeout          = 10

  // prevent absolute path change from causing an update on different machines
  lifecycle {
    ignore_changes = ["filename"]
  }
}

// Allow sns topic to invoke lambda
resource "aws_lambda_permission" "asg_mount_ebs_mount" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.main.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.main.arn}"
}

// Insure the SNS topic invokes the lambda
resource "aws_sns_topic_subscription" "asg_startup_commands" {
  topic_arn = "${aws_sns_topic.main.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.main.arn}"
}

// Create the role for autoscaling to use to post to the sns topic
resource "aws_iam_role" "main_hook" {
  name_prefix = "${local.name}_hook_"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "autoscaling.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

// Attach policy that will allow the hook to publish to the sns topic
resource "aws_iam_role_policy" "main_hook" {
  name_prefix = "${local.name}_hook_"
  role        = "${aws_iam_role.main_hook.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": "${aws_sns_topic.main.arn}"
    }
  ]
}
EOF
}

resource "aws_autoscaling_lifecycle_hook" "asg_mount_ebs_mount" {
  name                    = "autoscaling_copy_tags"
  autoscaling_group_name  = "${local.autoscaling_group_name}"
  default_result          = "CONTINUE"
  heartbeat_timeout       = 30
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_LAUNCHING"
  notification_metadata   = "${jsonencode(var.tags)}"
  notification_target_arn = "${aws_sns_topic.main.arn}"
  role_arn                = "${aws_iam_role.main_hook.arn}"
}

