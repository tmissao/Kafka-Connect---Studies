data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

resource "kubernetes_namespace" "kafka" {
  metadata {
    name = "kafka"
  }
}

resource "kubernetes_namespace" "nginx" {
  metadata {
    name = "nginx"
  }
}

resource "helm_release" "nginx" {
  name       = "nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = one(kubernetes_namespace.nginx.metadata).name
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
            BOOTSTRAP_BROKERS = aws_msk_cluster.this.bootstrap_brokers_sasl_scram
            USERNAME = var.kafka_connect_user
            PASSWORD_BASE64 = nonsensitive(base64encode(random_password.kafka_connect.result))
            DOCKER_REGISTRY_URL = aws_ecr_repository.this.repository_url
            KAFKA_CONNECT_IMAGE_TAG = "latest"
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
  version           = "1.0.0"
  values = [
        templatefile("${path.module}/helm/kafka-connectors/values.yaml", {})
  ]
  depends_on = [ 
        helm_release.kakfa_connect_cluster,
   ]
}