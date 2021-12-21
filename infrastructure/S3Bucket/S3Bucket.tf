resource "aws_iam_policy" "GH-Upload-To-S3" {
name   = "GH-Upload-To-S3"
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
            "arn:aws:s3:::${var.bucketname}",
            "arn:aws:s3:::${var.bucketname}/*",
        ]
    }
    ]
})
}
resource "aws_iam_user_policy_attachment" "uploadtos3attach" {
user       = "ghactions-ami"
policy_arn = aws_iam_policy.GH-Upload-To-S3.arn
}
resource "aws_iam_policy" "CodeDeploy-EC2-S3" {
name   = "CodeDeploy-EC2-S3"
policy =jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::${var.bucketname}",
                "arn:aws:s3:::${var.bucketname}/*",
            ]
        }
    ]
})
}
resource "aws_iam_role" "CodeDeployEC2ServiceRole" {
name = "CodeDeployEC2ServiceRole"
assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
        Service = "ec2.amazonaws.com"
        }
    },
    ]
})
}
resource "aws_iam_role_policy_attachment" "testattach" {
    role       = aws_iam_role.CodeDeployEC2ServiceRole.name
    policy_arn = aws_iam_policy.CodeDeploy-EC2-S3.arn
}
resource "aws_iam_instance_profile" "user_profile" {
    name = "CodeDeployEC2ServiceRole"
    role = aws_iam_role.CodeDeployEC2ServiceRole.name
}