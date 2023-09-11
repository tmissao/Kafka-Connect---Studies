module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = var.vpc.name 
  cidr = var.vpc.cidr 
  azs  = var.vpc.azs 
  private_subnets = var.vpc.private_subnets 
  public_subnets  = var.vpc.public_subnets 
  enable_nat_gateway = var.vpc.enable_nat_gateway 
  enable_vpn_gateway = var.vpc.enable_vpn_gateway 
  single_nat_gateway = var.vpc.single_nat_gateway
  one_nat_gateway_per_az = var.vpc.one_nat_gateway_per_az
  map_public_ip_on_launch = true
  tags = var.tags
}

resource "aws_security_group" "kafka_client" {
  name        = "Kafka Client SG"
  description = "Allow Connection with Kafka Client"
  vpc_id      = module.vpc.vpc_id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
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

resource "aws_security_group" "msk" {
  name        = "Kafka SG"
  description = "Allow Connection with Kafka"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description = "Zookeeper Plaintext"
    from_port       = 2181
    to_port         = 2181
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.kafka_client.id]
  }
  ingress {
    description = "Zookeeper TLS"
    from_port       = 2182
    to_port         = 2182
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.kafka_client.id]
  }
  ingress {
    description = "Broker Plaintext"
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.kafka_client.id]
  }
  ingress {
    description = "Broker TLS Private"
    from_port       = 9094
    to_port         = 9094
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.kafka_client.id]
  }
  ingress {
    description = "Broker TLS Public"
    from_port       = 9194
    to_port         = 9194
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.kafka_client.id]
  }
  ingress {
    description = "Broker SASL/SCRAM Private"
    from_port       = 9096
    to_port         = 9096
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.kafka_client.id]
  }
  ingress {
    description = "Broker SASL/SCRAM Public"
    from_port       = 9196
    to_port         = 9196
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.kafka_client.id]
  }
  ingress {
    description = "Broker AWS IAM Private"
    from_port       = 9098
    to_port         = 9098
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.kafka_client.id]
  }
  ingress {
    description = "Broker AWS IAM Public"
    from_port       = 9198
    to_port         = 9198
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.kafka_client.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}