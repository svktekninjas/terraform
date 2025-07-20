resource "kubernetes_service" "app_svc" {
  metadata {
    name      = "spring-cloud-config-service-new"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "spring-cloud-config-service-new"
    }

    port {
      port        = 8888
      target_port = 8888
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_deployment" "app_deploy" {
  metadata {
    name      = "spring-cloud-config-service-new"
    namespace = var.namespace
    labels = {
      app = "spring-cloud-config-service-new"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "spring-cloud-config-service-new"
      }
    }

    template {
      metadata {
        labels = {
          app = "spring-cloud-config-service-new"
        }
      }

      spec {
        image_pull_secrets {
          name = "ecr-secret"
        }

        container {
          name  = "spring-cloud-config-service-new"
          image = var.image

          port {
            container_port = 8888
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "app_route" {
  manifest = {
    apiVersion = "route.openshift.io/v1"
    kind       = "Route"
    metadata = {
      name      = "spring-cloud-config-service-new"
      namespace = var.namespace
    }
    spec = {
      to = {
        kind = "Service"
        name = kubernetes_service.app_svc.metadata[0].name
      }
      port = {
        targetPort = "8888"
      }
      tls = {
        termination = "edge"
      }
    }
  }
}

