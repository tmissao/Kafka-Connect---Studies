output "vpc" {
    value = {
        vpc_id = module.vpc.vpc_id,
        public_subnets = module.vpc.public_subnets
        private_subnets = module.vpc.private_subnets
    }
}

output "msk" {
    value = {
        id = aws_msk_cluster.this.arn
        zookeeper_connect_string = aws_msk_cluster.this.zookeeper_connect_string
        zookeeper_connect_string_tls = aws_msk_cluster.this.zookeeper_connect_string_tls
        bootstrap_brokers = aws_msk_cluster.this.bootstrap_brokers 
        bootstrap_brokers_sasl_scram = aws_msk_cluster.this.bootstrap_brokers_sasl_scram
        bootstrap_brokers_public_sasl_scram = aws_msk_cluster.this.bootstrap_brokers_public_sasl_scram
        bootstrap_brokers_sasl_iam = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
        bootstrap_brokers_public_sasl_iam = aws_msk_cluster.this.bootstrap_brokers_public_sasl_iam
    }
}

output "vm_kafka_client" {
    value = {
        arn = aws_instance.this.arn
        public_ip = aws_eip.this.public_ip
    }
}

output "kafka_users" {
    value = {
        manager = {
            username = var.kafka_manager_user
            password = nonsensitive(random_password.kafka_manager.result)
        }
        monitoring = {
            username = var.kafka_monitoring_user
            password = nonsensitive(random_password.kafka_monitoring.result)
        }
        connect = {
            username = var.kafka_connect_user
            password = nonsensitive(random_password.kafka_connect.result)
        }
    }
}