variable "aws_region" {
    default = "us-east-1"
}

variable "project" {
    default = "kafka-demo"
}

variable "vpc" {
    default = {
        name = "kafka-demo-vpc"
        cidr = "10.0.0.0/16"
        azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
        private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
        public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
        enable_nat_gateway = true
        enable_vpn_gateway = false
        single_nat_gateway = true
        one_nat_gateway_per_az = false
    }
}

variable "kafka" {
    default = {
        cluster_name = "kafka-demo"
        kafka_version = "2.8.1"
        number_of_broker_nodes = 3
        broker_node_group_info = {
            instance_type = "kafka.t3.small"
            connectivity_info = {
                public_access = {
                   type = "SERVICE_PROVIDED_EIPS" 
                }
            }
            storage_info = {
                ebs_storage_info  = {
                    min_volume_size = 1
                    autoscalling = {
                        enable = true
                        min_volume_size = 1
                        max_volume_size = 2000
                        target = 70
                    }
                    volume_size = 1000
                }
            }
            client_authentication = {
                unauthenticated = false
                sasl = {
                    scram = true
                    iam = true
                }
            }
            encryption_info = {
                encryption_in_transit = {
                    client_broker = "TLS"
                    in_cluster = "true"
                }
            }
            enable_monitoring = true
            logging_info = {
                cloudwatch_logs = {
                    enabled   = true
                    log_group = "kafka-demo"
                }
                s3 = {
                    enabled   = true
                    prefix = "logs/msk-"
                }
            }
        }
    }
}

variable "kafka_manager_user" {
    default = "kafka-manager"
}

variable "kafka_connect_user" {
    default = "kafka-connect"
}

variable "kafka_monitoring_user" {
    default = "kafka-monitoring"
}

variable "tags" {
    default = {
        scope = "demo"
        owner = "missão"
    }
}