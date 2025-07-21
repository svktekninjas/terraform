resource "kubernetes_service" "app_svc" {
  metadata {
    name      = "interviews-service-new"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "interviews-service-new"
    }

    port {
      port        = 8086
      target_port = 8086
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_deployment" "app_deploy" {
  metadata {
    name      = "interviews-service-new"
    namespace = var.namespace
    labels = {
      app = "interviews-service-new"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "interviews-service-new"
      }
    }

    template {
      metadata {
        labels = {
          app = "interviews-service-new"
        }
      }

      spec {
        image_pull_secrets {
          name = "ecr-secret"
        }

        container {
          name  = "interviews-service-new"
          image = var.image

          port {
            container_port = 8086
          }
          env {
            name = "SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL"
            value = "http://interviews-service:8086"
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
      name      = "interviews-service-new"
      namespace = var.namespace
    }
    spec = {
      to = {
        kind = "Service"
        name = kubernetes_service.app_svc.metadata[0].name
      }
      port = {
        targetPort = "8086"
      }
      tls = {
        termination = "edge"
      }
    }
  }
}

