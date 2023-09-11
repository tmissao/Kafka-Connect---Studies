resource "random_id" "this" {
  keepers = {}
  byte_length = 8
}

resource "aws_cloudwatch_log_group" "this" {
  name = var.kafka.broker_node_group_info.logging_info.cloudwatch_logs.log_group
  tags = var.tags
}

resource "aws_s3_bucket" "this" {
  bucket = "${var.project}-${random_id.this.dec}"
  force_destroy = true
  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_password" "kafka_connect" {
  length           = 32
  special          = true
  override_special = "@%-_+=:./"
}

resource "random_password" "kafka_monitoring" {
  length           = 32
  special          = true
  override_special = "@%-_+=:./"
}

resource "random_password" "kafka_manager" {
  length           = 32
  special          = true
  override_special = "@%-_+=:./"
}


resource "aws_kms_key" "this" {
  description = "Key for MSK Cluster Scram Secret Association"
}

resource "aws_secretsmanager_secret" "kafka_connect" {
  name = "AmazonMSK_kafkaconnect_auth"
  kms_key_id = aws_kms_key.this.id
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "kafka_connect" {
  secret_id     = aws_secretsmanager_secret.kafka_connect.id
  secret_string = jsonencode({
    username = var.kafka_connect_user
    password = random_password.kafka_connect.result
  })
}

resource "aws_secretsmanager_secret" "kafka_monitoring" {
  name = "AmazonMSK_kafkamonitoring_auth"
  kms_key_id = aws_kms_key.this.id
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "kafka_monitoring" {
  secret_id     = aws_secretsmanager_secret.kafka_monitoring.id
  secret_string = jsonencode({
    username = var.kafka_monitoring_user
    password = random_password.kafka_monitoring.result
  })
}

resource "aws_secretsmanager_secret" "kafka_manager" {
  name = "AmazonMSK_kafkamanager_auth"
  kms_key_id = aws_kms_key.this.id
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "kafka_manager" {
  secret_id     = aws_secretsmanager_secret.kafka_manager.id
  secret_string = jsonencode({
    username = var.kafka_manager_user
    password = random_password.kafka_manager.result
  })
}

resource "aws_msk_configuration" "this" {
  kafka_versions = [var.kafka.kafka_version]
  name           = "default"

  server_properties = file("${path.module}/templates/kafka.properties")
}

resource "aws_msk_cluster" "this" {
  cluster_name           = var.kafka.cluster_name
  kafka_version          = var.kafka.kafka_version
  number_of_broker_nodes = var.kafka.number_of_broker_nodes
  broker_node_group_info {
    instance_type = var.kafka.broker_node_group_info.instance_type
    client_subnets = module.vpc.public_subnets
    connectivity_info {
      public_access {
        type = var.kafka.broker_node_group_info.connectivity_info.public_access.type
      }
    }
    storage_info {
      ebs_storage_info {
        volume_size = var.kafka.broker_node_group_info.storage_info.ebs_storage_info.volume_size
      }
    }
    security_groups = [aws_security_group.msk.id]
  }
  configuration_info {
    arn = aws_msk_configuration.this.arn
    revision = aws_msk_configuration.this.latest_revision
  }
  client_authentication {
    unauthenticated = var.kafka.broker_node_group_info.client_authentication.unauthenticated
    sasl {
      scram = var.kafka.broker_node_group_info.client_authentication.sasl.scram
      iam = var.kafka.broker_node_group_info.client_authentication.sasl.iam
    }
  }
  encryption_info {
    encryption_in_transit {
        client_broker = var.kafka.broker_node_group_info.encryption_info.encryption_in_transit.client_broker
        in_cluster = var.kafka.broker_node_group_info.encryption_info.encryption_in_transit.in_cluster
    }
  }
  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = var.kafka.broker_node_group_info.enable_monitoring
      }
      node_exporter {
        enabled_in_broker = var.kafka.broker_node_group_info.enable_monitoring
      }
    }
  }
  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = var.kafka.broker_node_group_info.logging_info.cloudwatch_logs.enabled
        log_group = aws_cloudwatch_log_group.this.name
      }
      s3 {
        enabled = true
        bucket  = aws_s3_bucket.this.id
        prefix  = "logs/msk-"
      }
    }
  }
  tags =var.tags
}

resource "aws_msk_scram_secret_association" "this" {
  cluster_arn     = aws_msk_cluster.this.arn
  secret_arn_list = [
    aws_secretsmanager_secret.kafka_connect.arn, 
    aws_secretsmanager_secret.kafka_monitoring.arn,
    aws_secretsmanager_secret_version.kafka_manager.arn  
  ]
  depends_on = [
    aws_secretsmanager_secret_version.kafka_connect, 
    aws_secretsmanager_secret_version.kafka_monitoring,
    aws_secretsmanager_secret_version.kafka_manager,
  ]
}


resource "aws_appautoscaling_target" "kafka_storage" {
  count = var.kafka.broker_node_group_info.storage_info.ebs_storage_info.autoscalling.enable ? 1 : 0
  max_capacity       = var.kafka.broker_node_group_info.storage_info.ebs_storage_info.autoscalling.max_volume_size
  min_capacity       = var.kafka.broker_node_group_info.storage_info.ebs_storage_info.autoscalling.min_volume_size
  resource_id        = aws_msk_cluster.this.arn
  scalable_dimension = "kafka:broker-storage:VolumeSize"
  service_namespace  = "kafka"
}

resource "aws_appautoscaling_policy" "kafka_broker_scaling_policy" {
  count = var.kafka.broker_node_group_info.storage_info.ebs_storage_info.autoscalling.enable ? 1 : 0
  name               = "kafka-demo-broker-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_msk_cluster.this.arn
  scalable_dimension = one(aws_appautoscaling_target.kafka_storage).scalable_dimension
  service_namespace  = one(aws_appautoscaling_target.kafka_storage).service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "KafkaBrokerStorageUtilization"
    }
    target_value = var.kafka.broker_node_group_info.storage_info.ebs_storage_info.autoscalling.target
  }
}