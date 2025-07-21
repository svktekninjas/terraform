resource "kubernetes_service" "app_svc" {
  metadata {
    name      = "common-excel-service-new"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "common-excel-service-new"
    }

    port {
      port        = 8083
      target_port = 8083
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_deployment" "app_deploy" {
  metadata {
    name      = "common-excel-service-new"
    namespace = var.namespace
    labels = {
      app = "common-excel-service-new"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "common-excel-service-new"
      }
    }

    template {
      metadata {
        labels = {
          app = "common-excel-service-new"
        }
      }

      spec {
        image_pull_secrets {
          name = "ecr-secret"
        }

        container {
          name  = "common-excel-service-new"
          image = var.image

          port {
            container_port = 8083
          }
          env {
            name = "SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL"
            value = "http://common-excel-service:8083"
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
      name      = "common-excel-service-new"
      namespace = var.namespace
    }
    spec = {
      to = {
        kind = "Service"
        name = kubernetes_service.app_svc.metadata[0].name
      }
      port = {
        targetPort = "8083"
      }
      tls = {
        termination = "edge"
      }
    }
  }
}

