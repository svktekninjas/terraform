resource "kubernetes_service" "app_svc" {
  metadata {
    name      = "daily-submissions-service-new"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "daily-submissions-service-new"
    }

    port {
      port        = 8084
      target_port = 8084
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_deployment" "app_deploy" {
  metadata {
    name      = "daily-submissions-service-new"
    namespace = var.namespace
    labels = {
      app = "daily-submissions-service-new"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "daily-submissions-service-new"
      }
    }

    template {
      metadata {
        labels = {
          app = "daily-submissions-service-new"
        }
      }

      spec {
        image_pull_secrets {
          name = "ecr-secret"
        }

        container {
          name  = "daily-submissions-service-new"
          image = var.image

          port {
            container_port = 8084
          }
          env {
            name = "SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL"
            value = "http://daily-submissions-service:8084"
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
      name      = "daily-submissions-service-new"
      namespace = var.namespace
    }
    spec = {
      to = {
        kind = "Service"
        name = kubernetes_service.app_svc.metadata[0].name
      }
      port = {
        targetPort = "8084"
      }
      tls = {
        termination = "edge"
      }
    }
  }
}

