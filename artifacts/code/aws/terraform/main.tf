resource "aws_key_pair" "this" {
  key_name   = "kafka-client"
  public_key = file("${path.module}/keys/key.pub")
  tags = var.tags
}

data "aws_ami" "this" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "template_file" "init" {
    template = file("${path.module}/scripts/init.cfg")
}

data "template_file" "shell-script" {
    template = file("${path.module}/scripts/setup.sh")
    vars = {
        KAFKA_VERSION = var.kafka.kafka_version
        KAFKA_CLIENT_PROPERTIES = base64encode((templatefile("${path.module}/templates/kafka-client.properties", {})))
        BOOTSTRAP_BROKERS = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
        KAFKA_MANAGER_USER = var.kafka_manager_user
        KAFKA_CONNECT_USER = var.kafka_connect_user
        KAFKA_MONITORING_USER = var.kafka_monitoring_user
    }
}

data "template_cloudinit_config" "config" {
    gzip = true
    base64_encode = true
    part {
        filename = "init.cfg"
        content_type = "text/cloud-config"
        content = data.template_file.init.rendered
    }
    part {
        content_type = "text/x-shellscript"
        content = data.template_file.shell-script.rendered
    }
}

resource "aws_instance" "this" {
    ami           = data.aws_ami.this.id
    instance_type = "t3.small"
    key_name               = aws_key_pair.this.key_name
    subnet_id     = module.vpc.public_subnets[0]
    vpc_security_group_ids = [aws_security_group.kafka_client.id] 
    user_data_base64 = data.template_cloudinit_config.config.rendered
    user_data_replace_on_change = true
    associate_public_ip_address = true
    iam_instance_profile = aws_iam_instance_profile.instance_profile.name
    volume_tags = merge(
        var.tags,
        { Name = "kafka-client"}
    )
    tags = merge(
        var.tags,
        { Name = "kafka-client"}
    )
}

resource "aws_eip" "this" {
  domain = "vpc"
  instance                  = aws_instance.this.id
  depends_on                = [module.vpc]
  tags = merge(
      var.tags,
      { Name = "kafka-client"}
  )
}

resource "aws_ecr_repository" "this" {
  name                 = var.ecr.name
  image_tag_mutability = "MUTABLE"
  force_delete = true
  tags = var.tags
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "Allow to Read/Push"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:GetLifecyclePolicy",
      "ecr:GetLifecyclePolicyPreview",
      "ecr:ListTagsForResource",
      "ecr:DescribeImageScanFindings",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
  }
}

resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy     = data.aws_iam_policy_document.this.json
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.16.0"
  cluster_name    = var.eks.cluster_name
  cluster_version = var.eks.cluster_version
  cluster_endpoint_public_access  = true
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.public_subnets
  control_plane_subnet_ids = module.vpc.public_subnets
  eks_managed_node_groups = var.eks.managed_node_groups
  aws_auth_users = [
    {
      userarn  = data.aws_caller_identity.current.arn
      username = data.aws_caller_identity.current.id
      groups   = ["system:masters"]
    }
  ]
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }
  tags = var.tags
}

resource "null_resource" "build_kafka_connect_docker_image" {
  triggers = {
    DOCKERFILE_HASH = filemd5("${path.module}/docker/kafka-connect/Dockerfile")
  }
  provisioner "local-exec" {
    command = "/bin/bash ./${path.module}/scripts/build-image.sh"
    environment = {
      ECR_REGISTRY_REGION = var.aws_region
      ECR_REGISTRY_URL    = aws_ecr_repository.this.repository_url
      TAG = "apicurio"
      DOCKERFILE_PATH   = "${path.module}/docker/kafka-connect"
    }
  }
  depends_on = [
    aws_ecr_repository_policy.this
  ]
}

resource "aws_iam_user" "kafka" {
  name = "kafka"
  path = "/"
  tags = var.tags
}

resource "aws_iam_access_key" "kafka" {
  user = aws_iam_user.kafka.name
}

resource "aws_security_group" "rds" {
  name        = "RDS SG"
  description = "Allow Connection with Postgres"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description = "Postgres"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_db_subnet_group" "this" {
  name       = "main"
  subnet_ids = module.vpc.public_subnets
  tags = var.tags
}
resource "aws_db_instance" "this" {
  allocated_storage    = 20
  identifier = "demodb"
  db_name              = "generaldb"
  engine               = "postgres"
  engine_version       = "14"
  instance_class       = "db.t3.micro"
  username             = "adminuser"
  password             = "adminuser123X"
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot  = true
  publicly_accessible = true
}