locals {
    subnet_cidrs              = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
    subnet_availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
}
data "aws_iam_user" "ghactionsuser" {
  user_name = "ghactions-ami"
}
resource "aws_iam_user_policy_attachment" "ghactionsec2ami" {
  user       = data.aws_iam_user.ghactionsuser.user_name
  policy_arn = aws_iam_policy.gh-ec2-ami.arn
}
resource "aws_iam_policy" "gh-ec2-ami" {
  name        = "gh-ec2-ami"
  path        = "/"
  description = "gh-ec2-ami policy"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CopyImage",
        "ec2:CreateImage",
        "ec2:CreateKeypair",
        "ec2:CreateSecurityGroup",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteKeyPair",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteSnapshot",
        "ec2:DeleteVolume",
        "ec2:DeregisterImage",
        "ec2:DescribeImageAttribute",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeRegions",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSnapshots",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume",
        "ec2:GetPasswordData",
        "ec2:ModifyImageAttribute",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifySnapshotAttribute",
        "ec2:RegisterImage",
        "ec2:RunInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_vpc" "vpc" {
    cidr_block = var.vpc_cidr
    tags = {
        Name = format("%s-%s", "vpc", "vpc_${terraform.workspace}")
    }
}
resource "aws_subnet" "subnet" {
    depends_on = [aws_vpc.vpc]
    count      = length(local.subnet_cidrs)
    vpc_id            = aws_vpc.vpc.id
    cidr_block        = local.subnet_cidrs[count.index]
    availability_zone = local.subnet_availability_zones[count.index]
}
resource "aws_internet_gateway" "internet_gateway" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = format("%s-%s", "igw", "igw_${terraform.workspace}")
    }
}
resource "aws_route_table" "route_table" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.internet_gateway.id
    }
    tags = {
        Name = format("%s-%s", "rt", "rt_${terraform.workspace}")
    }
}
resource "aws_route_table_association" "route_association" {
    count          = length(local.subnet_cidrs)
    subnet_id      = element(aws_subnet.subnet.*.id, count.index)
    route_table_id = aws_route_table.route_table.id
}
resource "aws_security_group" "loadbalancer_sg" {
  name = "loadbalancer_sg"
  description = "Loadbalancer security group"
  vpc_id      = aws_vpc.vpc.id
  egress {  
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  tags = {
    Name = "loadbalancer_sg"
  }

}
resource "aws_security_group" "application"{
    name        = "application"
    description = "Application inbound traffic"
    vpc_id      = aws_vpc.vpc.id
    ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = ["${aws_security_group.loadbalancer_sg.id}"]
  }
  ingress {
    from_port       = 22 
    to_port         = 22   
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "database" {
    name        = "database"
    description = "Database inbound traffic"
    vpc_id      = aws_vpc.vpc.id
    ingress = [
        {
        description      = "MySQL"
        from_port        = 3306
        to_port          = 3306
        protocol         = "tcp"
        cidr_blocks      = []
        ipv6_cidr_blocks = []
        prefix_list_ids  = []
        security_groups  = [aws_security_group.application.id]
        self             = false
        }
    ]
    egress = [
        {
        description      = "for all outgoing traffic"
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
        prefix_list_ids  = []
        security_groups  = []
        self             = false
        }
    ]
}
data "aws_iam_user" "selected1" {
user_name = "ghactions-app"
}
data "aws_iam_role" "currRole" {
name = "CodeDeployEC2ServiceRole"
}
data "aws_iam_policy" "currPolicy" {
arn = "arn:aws:iam::${var.user_id}:policy/CodeDeploy-EC2-S3"
}
data "aws_iam_policy" "currPolicyUploadToS3" {
arn = "arn:aws:iam::${var.user_id}:policy/GH-Upload-To-S3"
}
resource "aws_iam_user_policy_attachment" "attachUserUploadS3Attach" {
user       = "ghactions-app"
policy_arn = data.aws_iam_policy.currPolicy.arn
}
resource "aws_iam_role_policy_attachment" "test-attach1" {
    role       = data.aws_iam_role.currRole.name
    policy_arn = data.aws_iam_policy.currPolicy.arn
}
resource "aws_iam_role_policy_attachment" "test-attach" {
role       = data.aws_iam_role.currRole.name
policy_arn = data.aws_iam_policy.currPolicyUploadToS3.arn
}
resource "aws_iam_role_policy_attachment" "CloudWatchAgentServerPolicy" {
  role       = data.aws_iam_role.currRole.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
//****************************************************************************
resource "aws_db_subnet_group" "db-subnet" {
name       = "db-subnet"
subnet_ids = ["${aws_subnet.subnet.*.id[1]}", "${aws_subnet.subnet.*.id[0]}","${aws_subnet.subnet.*.id[2]}"]
}
resource "aws_db_parameter_group" "aurora_mysql" {
    name        = "my-rds-param"
    family = "mysql5.7"
    description = "My Rds Parameter group"
    parameter {
        name  = "character_set_server"
        value = "utf8"
    }
    parameter {
        name  = "character_set_client"
        value = "utf8"
    }
    parameter {
        name = "general_log"
        value = "0"  
    }
    parameter {
        name = "log_output"
        value = "FILE"
    }
    lifecycle {
        create_before_destroy = true
    }
}
resource "aws_db_instance" "csye6225" {
    allocated_storage    = 10
    engine               = "mysql"
    engine_version       = "5.7"
    instance_class       = "db.t3.micro"
    name                 = "csye6225"
    username             = "csye6225"
    password             = "csye6225"
    identifier             = "csye6225"
    multi_az             = false
    availability_zone   = "us-west-2a"
    db_subnet_group_name   = aws_db_subnet_group.db-subnet.name
    vpc_security_group_ids = [aws_security_group.database.id]
    parameter_group_name = aws_db_parameter_group.aurora_mysql.name
    storage_encrypted=true
    ca_cert_identifier = data.aws_rds_certificate.rds_certificate.id
    kms_key_id = aws_kms_key.encrypt_rds.arn
    publicly_accessible    = false
    skip_final_snapshot  = true
    backup_retention_period = 1
    tags = {
        Name = format("csye6225")
    }
}
resource "aws_db_instance" "replica" {
  identifier          = "csye6225-read-replica"
  replicate_source_db = aws_db_instance.csye6225.identifier
  instance_class      = aws_db_instance.csye6225.instance_class
  availability_zone   = "us-west-2c"
  vpc_security_group_ids = [aws_security_group.database.id]
  parameter_group_name = aws_db_parameter_group.aurora_mysql.name
  publicly_accessible    = false
  skip_final_snapshot  = true
  tags = {
        Name = format("csye6225")
    }
}
data "aws_rds_certificate" "rds_certificate" {
  latest_valid_till = true
}
resource "aws_iam_instance_profile" "user_profile_aniketh_123" {
  name = "user_profile_aniketh_123"
  role = data.aws_iam_role.currRole.name
}
data "aws_iam_user" "selected2" {
user_name = "ghactions-ami"
}
data "aws_caller_identity" "current" {}
resource "aws_iam_policy" "GH-Code-Deploy" {
name   = "GH-Code-Deploy"
policy = <<POLICY
{
"Version": "2012-10-17",
"Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "codedeploy:RegisterApplicationRevision",
            "codedeploy:GetApplicationRevision"
        ],
        "Resource": [
            "arn:aws:codedeploy:${var.aws_region}:${var.user_id}:application:csye6225-webapp"
        ]
        },
        {
        "Effect": "Allow",
        "Action": [
            "codedeploy:CreateDeployment",
            "codedeploy:GetDeployment"
        ],
        "Resource": [
            "*"
        ]
        },
        {
        "Effect": "Allow",
        "Action": [
            "codedeploy:GetDeploymentConfig"
        ],
        "Resource": [
            "arn:aws:codedeploy:${var.aws_region}:${var.user_id}:deploymentconfig:CodeDeployDefault.OneAtATime",
            "arn:aws:codedeploy:${var.aws_region}:${var.user_id}:deploymentconfig:CodeDeployDefault.HalfAtATime",
            "arn:aws:codedeploy:${var.aws_region}:${var.user_id}:deploymentconfig:CodeDeployDefault.AllAtOnce"
        ]
    }
]
}
POLICY              
}
resource "aws_iam_user_policy_attachment" "code-Deploy-attach" {
user       = data.aws_iam_user.selected2.user_name
policy_arn = aws_iam_policy.GH-Code-Deploy.arn
}
resource "aws_iam_role" "CodeDeployServiceRole" {
name = "CodeDeployServiceRole"
assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
    {
        "Sid": "",
        "Effect": "Allow",
        "Principal": {
            "Service": [
            "codedeploy.amazonaws.com"
            ]
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "code_deploy_role_attachment" {
    role       = "${aws_iam_role.CodeDeployServiceRole.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}
resource "aws_codedeploy_app" "csye6225-webapp" {
    name             = "csye6225-webapp"
}
resource "aws_codedeploy_deployment_group" "csye6225-webapp-deployment" {
    app_name              = aws_codedeploy_app.csye6225-webapp.name
    deployment_group_name = "csye6225-webapp-deployment"
    deployment_config_name = "CodeDeployDefault.AllAtOnce"
    service_role_arn      = aws_iam_role.CodeDeployServiceRole.arn
    auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
    }
    ec2_tag_set {
    ec2_tag_filter {
        key   = "Name"
        type  = "KEY_AND_VALUE"
        value = "webapp"
    }
    }
    load_balancer_info {
        target_group_pair_info {
            prod_traffic_route {
                listener_arns = ["${aws_lb_listener.lb_listener.arn}"]
            }
            target_group {
                name = "${aws_lb_target_group.lb-target-group.name}"
            }
            
        }
    }
    autoscaling_groups = ["${aws_autoscaling_group.autoscaling_group_webapp.name}"]
}
data "aws_ami" "pre_built_ami" {
  owners = [var.dev_user_id]
  most_recent = true
}
resource "aws_launch_configuration" "asg_launch_config_prod" {
  name_prefix   = "asg_launch_config_prod"
  image_id      = data.aws_ami.pre_built_ami.id
  instance_type = "t3.2xlarge"
  key_name               = "Demo1"
  security_groups = [aws_security_group.application.id]
  associate_public_ip_address = true
  iam_instance_profile = "${aws_iam_instance_profile.user_profile_aniketh_123.name}"
  user_data              = <<EOF
#!/bin/bash
sudo su
sudo apt update

#DB1
echo export DB_HOSTNAME=${aws_db_instance.csye6225.address} >> /etc/environment
echo export DB_PORT=3306 >> /etc/environment
echo export DB_DATABASE=csye6225 >> /etc/environment
echo export DB_USER=csye6225 >> /etc/environment
echo export DB_PASSWORD=csye6225 >> /etc/environment

#DB2
echo export DB_HOSTNAME2=${aws_db_instance.replica.address} >> /etc/environment
// echo export DB_HOSTNAME2=csye6225-read-replica.c02nl79rv62h.us-west-2.rds.amazonaws.com >> /etc/environment
echo export DB_PORT2=3306 >> /etc/environment
echo export DB_DATABASE2=csye6225 >> /etc/environment
echo export DB_USER2=csye6225 >> /etc/environment
echo export DB_PASSWORD2=csye6225 >> /etc/environment

echo export aws_access_key_id=DUMMYVALUE >> /etc/environment
echo export aws_secret_access_key=DUMMYVALUE >> /etc/environment
echo export aws_region=us-west-2 >> /etc/environment
echo export aws_bucket_name=codedeploy.adckjndqqwdnjdqnjcwfrjfr >> /etc/environment
source /etc/environment
EOF
  root_block_device {
    volume_type = "gp2"
    volume_size = 20
    delete_on_termination = true
    encrypted = true
  }
  lifecycle {
    create_before_destroy = true
  }

}
resource "aws_autoscaling_group" "autoscaling_group_webapp" {
  name                 = "autoscaling_group_webapp"
  launch_configuration = aws_launch_configuration.asg_launch_config_prod.name
  min_size             = 3
  max_size             = 5
  desired_capacity     = 3
  default_cooldown     = 60
  health_check_grace_period = 1200
  target_group_arns = [aws_lb_target_group.lb-target-group.arn]
  vpc_zone_identifier=["${aws_subnet.subnet.*.id[1]}", "${aws_subnet.subnet.*.id[0]}","${aws_subnet.subnet.*.id[2]}"]
  lifecycle {
    create_before_destroy = true
  }
  tag {
    key                 = "Name"
    value               = "webapp"
    propagate_at_launch = true
  }
}
resource "aws_autoscaling_policy" "WebServerScaleUpPolicy" {
  name                   = "WebServerScaleUpPolicy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group_webapp.name
}
resource "aws_autoscaling_policy" "WebServerScaleDownPolicy" {
  name                   = "WebServerScaleDownPolicy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group_webapp.name
}
resource "aws_cloudwatch_metric_alarm" "CPUAlarmHigh" {
  alarm_name          = "CPUAlarmHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "Scale-up if CPU > 5% for 60 seconds"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group_webapp.name
  }
  alarm_actions     = [aws_autoscaling_policy.WebServerScaleUpPolicy.arn]
}
resource "aws_cloudwatch_metric_alarm" "CPUAlarmLow" {
  alarm_name          = "CPUAlarmLow"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "3"
  alarm_description   = "Scale-down if CPU < 3% for 60 seconds"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group_webapp.name
  }
  alarm_actions     = [aws_autoscaling_policy.WebServerScaleDownPolicy.arn]
}
//***************************************************************************
resource "aws_kms_key" "encrypt_ebs_volumes" {
    description = "Key to encrypt EBS volumes"
    key_usage = "ENCRYPT_DECRYPT"
    customer_master_key_spec = "SYMMETRIC_DEFAULT"
    deletion_window_in_days = 7
    tags = {
    Name = "encrypt_ebs_volumes"
    }
    policy      = <<EOF
    {
    "Version": "2012-10-17",
    "Statement": [
    {
    "Sid": "Enable IAM User Permissions",
    "Effect": "Allow",
    "Principal": {
    "AWS": "arn:aws:iam::${var.user_id}:root"
    },
    "Action": "kms:*",
    "Resource": "*"
    },
    {
    "Sid": "Add service role",
    "Effect": "Allow",
    "Principal": {
    "AWS": "arn:aws:iam::${var.user_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
    },
    "Action": "kms:*",
    "Resource": "*"
    }
    ]
    }
    EOF
}

resource "aws_ebs_default_kms_key" "encrypt_ebs_volumes" {
    key_arn = aws_kms_key.encrypt_ebs_volumes.arn
}

resource "aws_kms_key" "encrypt_rds" {
  description             = "KMS key to encrypt RDS"
  deletion_window_in_days = 10
  tags = {
    Alias = "encrypt_rds"
  }
}

resource "aws_iam_policy" "kms_iam_policy" {
  name        = "kms_iam_policy"
  path        = "/"
  description = "kms_iam_policy policy"
   policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Sid": "Aa1",
        "Effect": "Allow",
        "Action": "kms:*",
        "Resource": "*"
    },
    {
        "Sid": "Aa2",
        "Effect": "Allow",
        "Action": [
                  "kms:Create*",
                  "kms:Describe*",
                  "kms:Enable*",
                  "kms:List*",
                  "kms:Put*",
                  "kms:Update*",
                  "kms:Revoke*",
                  "kms:Disable*",
                  "kms:Get*",
                  "kms:Delete*",
                  "kms:TagResource",
                  "kms:UntagResource",
                  "kms:ScheduleKeyDeletion",
                  "kms:CancelKeyDeletion"
        ],
        "Resource": "*"
    },
    {
        "Sid": "Aa3",
        "Effect": "Allow",
        "Action": [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey"
        ],
        "Resource": "*"
    },
    {
        "Sid": "Aa4",
        "Effect": "Allow",
        "Action": [
            "kms:CreateGrant",
            "kms:ListGrants",
            "kms:RevokeGrant"
        ],
        "Resource": "*",
        "Condition": {
        "Bool": {
        "kms:GrantIsForAWSResource": "true"
                }
                      }
    },
    {
        "Sid": "Aa5",
        "Effect": "Allow",
        "Action": "kms:*",
        "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_user_policy_attachment" "ghactions_attach_kms_policy" {
  user       = data.aws_iam_user.selected1.user_name
  policy_arn = aws_iam_policy.kms_iam_policy.arn
}
//***************************************************************************
resource "aws_lb" "load-balancer" {
  name               = "load-balancer"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    ="ipv4"
  security_groups    = [aws_security_group.loadbalancer_sg.id]
  subnets            = ["${aws_subnet.subnet.*.id[1]}", "${aws_subnet.subnet.*.id[0]}","${aws_subnet.subnet.*.id[2]}"]
  enable_deletion_protection = false
  tags = {
    Name = "webapp"
  }
}
data "aws_route53_zone" "fetched_zone" {
  name         = var.domain
  private_zone = false
}
resource "aws_route53_record" "route53_record" {
  zone_id  = var.route53_zone_id
  name     = var.domain
  type     = "A"
  alias {
    name                   = aws_lb.load-balancer.dns_name
    zone_id                = aws_lb.load-balancer.zone_id
    evaluate_target_health = true
  }
}
data "aws_acm_certificate" "prod_ssl_cert" {
  domain   = var.domain
  statuses = ["ISSUED"]
}
resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.load-balancer.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   =  data.aws_acm_certificate.prod_ssl_cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-target-group.arn
  }
}
resource "aws_lb_target_group" "lb-target-group" {
  name     = "lb-target-group"
  port     = 8080
  protocol = "HTTP"
  health_check {
    interval=30
    timeout=5
    healthy_threshold=3
    unhealthy_threshold=5
    path="/healthCheck"
  }
  vpc_id   = aws_vpc.vpc.id
}

resource "aws_sns_topic" "sns_topic" {
  name = "sns_topic"
}
resource "aws_iam_role_policy_attachment" "SNSPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
  role       = data.aws_iam_role.currRole.name
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

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

resource "aws_iam_role_policy_attachment" "lambda_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_lambda_function" "lambda_function" {
  filename      = "Archive.zip"
  function_name = "serverless"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  timeout       = 5
  runtime = "nodejs12.x"

  environment {
    variables = {
      DYNANODB_TABLE = aws_dynamodb_table.dynamodb_instance.id
    }
  }
}
resource "aws_sns_topic_subscription" "user_updates_sns_target" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.lambda_function.arn
}

resource "aws_lambda_permission" "lambda_sns_permission" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sns_topic.arn
}

resource "aws_iam_policy" "update_lambda_policy" {
  name        = "update_lambda_policy"
  description = "Github actions policy to update lambda function code"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:UpdateFunctionCode"
            ],
            "Resource": [
                "${aws_lambda_function.lambda_function.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_user_policy_attachment" "serverless_attachment" {
  user       = data.aws_iam_user.selected1.user_name
  policy_arn = aws_iam_policy.update_lambda_policy.arn
}


resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  path        = "/"
  description = "This is the policy for lambda function"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                      "dynamodb:BatchGetItem",
                      "dynamodb:GetItem",
                      "dynamodb:Query",
                      "dynamodb:Scan",
                      "dynamodb:BatchWriteItem",
                      "dynamodb:PutItem",
                      "dynamodb:UpdateItem"
			      ],
			      "Resource": "${aws_dynamodb_table.dynamodb_instance.arn}"
        },
        {
          "Effect": "Allow",
          "Action": [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource": "arn:aws:logs:${var.aws_region}:${var.user_id}:*"
        },
        {
          "Effect": "Allow",
          "Action": "logs:CreateLogGroup",
          "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_policy.arn
  role       = aws_iam_role.lambda_role.name
}
resource "aws_iam_role_policy_attachment" "lambda_ses_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_dynamodb_table" "dynamodb_instance" {
  name           = "dynamodb_instance"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "OPT"
    type = "S"
  }
  attribute {
    name = "MessageType"
    type = "S"
  }
  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }
  global_secondary_index {
    name               = "OPTIndex"
    hash_key           = "OPT"
    range_key          = "MessageType"
    write_capacity     = 10
    read_capacity      = 10
    projection_type    = "INCLUDE"
    non_key_attributes = ["id"]
  }


  tags = {
    Name = "dynamodb_instance"
  }
}
resource "aws_s3_bucket" "lambdabucket" {
  bucket = var.lambda_bucket
  acl    = "private"
  force_destroy = true


  server_side_encryption_configuration {    
    rule {     
        apply_server_side_encryption_by_default { sse_algorithm = "AES256"}
      }
  }

  lifecycle_rule {
    id      = "log"
    enabled = true
    transition {
      days          = 30
      storage_class = "STANDARD_IA" # or "ONEZONE_IA"
    }
  }

  tags = {
    Name = "lambdabucket"
  }
}
resource "aws_s3_bucket_public_access_block" "serverlessBucketRemovePublicAccess" {
  bucket = aws_s3_bucket.lambdabucket.id
  block_public_acls = true
  block_public_policy = true
  restrict_public_buckets = true
  ignore_public_acls = true
}
resource "aws_iam_user_policy_attachment" "ghactions_attach_gh_serverless_upload_to_s3_policy" {
user       = "ghactions-app"
policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}
resource "aws_iam_policy" "Lambda-Get-S3" {
name   = "Lambda_Bucket"
policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
    {
        "Action" : [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject"
        ],
        "Effect" : "Allow",
        "Resource": [
            "arn:aws:s3:::${var.lambda_bucket}",
            "arn:aws:s3:::${var.lambda_bucket}/*",
        ]
    }
    ]
})
}
resource "aws_iam_role_policy_attachment" "lambda_bucket_role_policy_attachment" {
role       = aws_iam_role.lambda_role.name
policy_arn = aws_iam_policy.Lambda-Get-S3.arn
}