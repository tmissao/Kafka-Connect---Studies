data "aws_iam_policy_document" "allow_msk_to_read_secrets" {
  statement {
    sid    = "AWSKafkaResourcePolicy"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["kafka.amazonaws.com"]
    }
    actions   = ["secretsmanager:getSecretValue"]
    resources = [
        aws_secretsmanager_secret.kafka_connect.arn, 
        aws_secretsmanager_secret.kafka_monitoring.arn,
        aws_secretsmanager_secret_version.kafka_manager.arn
    ]
  }
}

resource "aws_secretsmanager_secret_policy" "kafka_connect" {
  secret_arn = aws_secretsmanager_secret.kafka_connect.arn
  policy     = data.aws_iam_policy_document.allow_msk_to_read_secrets.json
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions   = ["sts:AssumeRole"]
  }
}

data aws_iam_policy_document "manage_msk" {
  statement {
    actions = [
        "kafka-cluster:DescribeCluster",
        "kafka-cluster:AlterCluster",
        "kafka-cluster:Connect"
    ]
    resources = [aws_msk_cluster.this.arn]
  }
  statement {
    actions = [
        "kafka-cluster:DeleteGroup",
        "kafka-cluster:DescribeCluster",
        "kafka-cluster:ReadData",
        "kafka-cluster:DescribeTopicDynamicConfiguration",
        "kafka-cluster:AlterTopicDynamicConfiguration",
        "kafka-cluster:AlterGroup",
        "kafka-cluster:AlterClusterDynamicConfiguration",
        "kafka-cluster:AlterTopic",
        "kafka-cluster:CreateTopic",
        "kafka-cluster:DescribeTopic",
        "kafka-cluster:AlterCluster",
        "kafka-cluster:DescribeGroup",
        "kafka-cluster:DescribeClusterDynamicConfiguration",
        "kafka-cluster:Connect",
        "kafka-cluster:DeleteTopic",
        "kafka-cluster:WriteData"
    ]
    resources = [replace("${aws_msk_cluster.this.arn}/*", ":cluster/", ":topic/")]
  }
  statement {
    actions = [
        "kafka-cluster:AlterGroup",
        "kafka-cluster:DescribeGroup"
    ]
    resources = [replace("${aws_msk_cluster.this.arn}/*", ":cluster/", ":group/")]
  }
}

resource "aws_iam_role" "ec2_iam_role" {
  name = "ec2_iam_role"
  assume_role_policy = "${data.aws_iam_policy_document.ec2_assume_role.json}"
}

resource "aws_iam_role_policy" "join_policy" {
  name       = "allow_ec2_to_manage_msk_demo"
  role       = aws_iam_role.ec2_iam_role.name
  policy = data.aws_iam_policy_document.manage_msk.json
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "allow_ec2_to_manage_msk_demo"
  role = aws_iam_role.ec2_iam_role.name
}

data "aws_iam_policy_document" "kafka" {
  statement {
    effect    = "Allow"
    actions   = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      aws_s3_bucket.this.arn,
    ]
  }
  statement {
    effect    = "Allow"
    actions   = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:AbortMultipartUpload",
      "s3:PutObjectTagging"
    ]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]
  }
  statement {
    effect    = "Allow"
    actions   = [
      "s3:ListAllMyBuckets"
    ]
    resources = [
      "arn:aws:s3:::*"
    ]
  }
}

resource "aws_iam_user_policy" "kafka" {
  name   = "AllowKafkatoWriteonS3"
  user   = aws_iam_user.kafka.name
  policy = data.aws_iam_policy_document.kafka.json
}