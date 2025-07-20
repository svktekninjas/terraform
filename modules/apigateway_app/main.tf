resource "kubernetes_service" "app_svc" {
  metadata {
    name      = "apigateway-app-new"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "apigateway-app-new"
    }

    port {
      port        = 8765
      target_port = 8765
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_deployment" "app_deploy" {
  metadata {
    name      = "apigateway-app-new"
    namespace = var.namespace
    labels = {
      app = "apigateway-app-new"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "apigateway-app-new"
      }
    }

    template {
      metadata {
        labels = {
          app = "apigateway-app-new"
        }
      }

      spec {
        image_pull_secrets {
          name = "ecr-secret"
        }

        container {
          name  = "apigateway-app-new"
          image = var.image

          port {
            container_port = 8765
          }
          env {
            name  = "SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL"
            value = "http://apigateway-app:8765"
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
      name      = "apigateway-app-new"
      namespace = var.namespace
    }
    spec = {
      to = {
        kind = "Service"
        name = kubernetes_service.app_svc.metadata[0].name
      }
      port = {
        targetPort = "8765"
      }
      tls = {
        termination = "edge"
      }
    }
  }
}

