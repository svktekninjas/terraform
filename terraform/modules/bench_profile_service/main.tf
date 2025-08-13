resource "kubernetes_service" "app_svc" {
  metadata {
    name      = "bench-profile-service-new"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "bench-profile-service-new"
    }

    port {
      port        = 8081
      target_port = 8081
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_deployment" "app_deploy" {
  metadata {
    name      = "bench-profile-service-new"
    namespace = var.namespace
    labels = {
      app = "bench-profile-service-new"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "bench-profile-service-new"
      }
    }

    template {
      metadata {
        labels = {
          app = "bench-profile-service-new"
        }
      }

      spec {
        image_pull_secrets {
          name = "ecr-secret"
        }

        container {
          name  = "bench-profile-service-new"
          image = var.image

          port {
            container_port = 8081
          }
          env {
            name = "SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL"
            value = "http://bench-profile-service-new:8081"
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
      name      = "bench-profile-service-new"
      namespace = var.namespace
    }
    spec = {
      to = {
        kind = "Service"
        name = kubernetes_service.app_svc.metadata[0].name
      }
      port = {
        targetPort = "8081"
      }
      tls = {
        termination = "edge"
      }
    }
  }
}

