data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

resource "kubernetes_namespace" "kafka" {
  metadata {
    name = "kafka"
  }
}

resource "kubernetes_secret_v1" "aws_credentials" {
  metadata {
    name = "aws-credentials"
    namespace = kubernetes_namespace.kafka.metadata.0.name
  }
  data = {
    accessKeyId = aws_iam_access_key.kafka.id
    secretAccessKey = aws_iam_access_key.kafka.secret
  }
}

resource "kubernetes_role_v1" "allow_kafka_connect_read_secrets" {
  metadata {
    name = "allow-kafka-connect-read-screts"
    namespace = kubernetes_namespace.kafka.metadata.0.name
  }
  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    verbs          = ["get", "list"]
  }
}

resource "kubernetes_role_binding" "allow_kafka_connect_read_secrets" {
  metadata {
    name      = "kafka-connect-read-secrets"
    namespace = kubernetes_namespace.kafka.metadata.0.name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.allow_kafka_connect_read_secrets.metadata.0.name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "${var.kafka_connect_cluster.name}-connect"
    namespace = kubernetes_namespace.kafka.metadata.0.name
  }
  depends_on = [ 
    helm_release.kakfa_connect_cluster
  ]
}

resource "helm_release" "strimzi" {
  namespace = kubernetes_namespace.kafka.metadata.0.name
  wait      = true
  timeout   = 600
  name = "strimzi"
  repository = "https://strimzi.io/charts/"
  chart      = "strimzi-kafka-operator"
  version    = "0.36.1"
  values = [
    templatefile("${path.module}/helm/strimzi/values.yaml", {
    })
  ]
}

resource "helm_release" "kakfa_connect_cluster" {
  namespace = kubernetes_namespace.kafka.metadata.0.name
  wait      = true
  force_update = true
  recreate_pods = true
  timeout   = 600
  name = "kafka-connect-cluster"
  chart      = "./${path.module}/helm/kafka-connect-cluster"
  version           = "1.0.1"
  values = [
        templatefile("${path.module}/helm/kafka-connect-cluster/values.yaml", {
            KAFKA_CONNECT_CLUSTER_NAME = var.kafka_connect_cluster.name
            BOOTSTRAP_BROKERS = aws_msk_cluster.this.bootstrap_brokers_sasl_scram
            USERNAME = var.kafka_connect_user
            PASSWORD_BASE64 = nonsensitive(base64encode(random_password.kafka_connect.result))
            DOCKER_REGISTRY_URL = aws_ecr_repository.this.repository_url
            KAFKA_CONNECT_IMAGE_TAG = "apicurio"
        })
  ]
  depends_on = [ 
        helm_release.strimzi,
        null_resource.build_kafka_connect_docker_image
   ]
}

resource "helm_release" "kakfa_connectors" {
  namespace = kubernetes_namespace.kafka.metadata.0.name
  wait      = true
  force_update = true
  recreate_pods = true
  timeout   = 600
  name = "kafka-connectors"
  chart      = "./${path.module}/helm/kafka-connectors"
  version           = "1.0.1"
  values = [
        templatefile("${path.module}/helm/kafka-connectors/values.yaml", {
          KAFKA_CONNECT_CLUSTER_NAME = var.kafka_connect_cluster.name
          AWS_ACCESS_KEY_ID = aws_iam_access_key.kafka.id
          AWS_SECRET_ACCESS_KEY = aws_iam_access_key.kafka.secret
          S3_BUCKET_NAME = aws_s3_bucket.this.bucket
          S3_REGION = var.aws_region
        })
  ]
  depends_on = [ 
        helm_release.kakfa_connect_cluster
   ]
}

resource "helm_release" "apicurio" {
  namespace = kubernetes_namespace.kafka.metadata.0.name
  wait      = true
  force_update = true
  recreate_pods = true
  timeout   = 600
  name = "apicurio-schema-registry"
  chart      = "./${path.module}/helm/apicurio-schema-registry"
  version           = "1.0.0"
  values = [
        templatefile("${path.module}/helm/apicurio-schema-registry/values.yaml", {
          APP_NAME = var.schema_registry.name
          BOOTSTRAP_BROKERS = aws_msk_cluster.this.bootstrap_brokers_sasl_scram
          KAFKA_USERNAME = var.kafka_connect_user
          KAFKA_PASSWORD = random_password.kafka_connect.result
        })
  ]
}

resource "kubernetes_config_map_v1" "kafka_ui_cm" {
  metadata {
    name = "kafka-ui"
    namespace = kubernetes_namespace.kafka.metadata.0.name
  }

  data = {
    KAFKA_CLUSTERS_0_NAME = var.kafka.cluster_name
    KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS = aws_msk_cluster.this.bootstrap_brokers_sasl_scram
    KAFKA_CLUSTERS_0_PROPERTIES_SECURITY_PROTOCOL = "SASL_SSL"
    KAFKA_CLUSTERS_0_PROPERTIES_SASL_MECHANISM = "SCRAM-SHA-512"
    KAFKA_CLUSTERS_0_PROPERTIES_SASL_JAAS_CONFIG= "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"${var.kafka_manager_user}\" password=\"${random_password.kafka_manager.result}\";"
    KAFKA_CLUSTERS_0_METRICS_PORT = 11001
    KAFKA_CLUSTERS_0_METRICS_TYPE = "PROMETHEUS"
    KAFKA_CLUSTERS_0_KAFKACONNECT_0_NAME = var.kafka_connect_cluster.name
    KAFKA_CLUSTERS_0_KAFKACONNECT_0_ADDRESS = "http://${var.kafka_connect_cluster.name}-connect-api:8083"
    # Although Apicurio API is /apis/registry/v2 it is necessary to use the confluent schema registry compatibility api
    KAFKA_CLUSTERS_0_SCHEMAREGISTRY = "http://${var.schema_registry.name}:8080/apis/ccompat/v7"
    DYNAMIC_CONFIG_ENABLED = "true"
  }
}

resource "helm_release" "kafka_ui" {
  namespace = kubernetes_namespace.kafka.metadata.0.name
  wait      = true
  force_update = true
  recreate_pods = true
  timeout   = 600
  name = "kafka-ui"
  repository = "https://provectus.github.io/kafka-ui-charts"
  chart      = "kafka-ui"
  version    = "0.7.5"
  values = [
        templatefile("${path.module}/helm/kafka-ui/values.yaml", {
          CONFIGMAP_NAME = kubernetes_config_map_v1.kafka_ui_cm.metadata.0.name
        })
  ]
}