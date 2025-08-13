resource "kubernetes_service" "app_svc" {
  metadata {
    name      = "placements-service-new"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "placements-service-new"
    }

    port {
      port        = 8085
      target_port = 8085
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_deployment" "app_deploy" {
  metadata {
    name      = "placements-service-new"
    namespace = var.namespace
    labels = {
      app = "placements-service-new"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "placements-service-new"
      }
    }

    template {
      metadata {
        labels = {
          app = "placements-service-new"
        }
      }

      spec {
        image_pull_secrets {
          name = "ecr-secret"
        }

        container {
          name  = "placements-service-new"
          image = var.image

          port {
            container_port = 8085
          }
          env {
            name = "SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL"
            value = "http://placements-service:8085"
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
      name      = "placements-service-new"
      namespace = var.namespace
    }
    spec = {
      to = {
        kind = "Service"
        name = kubernetes_service.app_svc.metadata[0].name
      }
      port = {
        targetPort = "8085"
      }
      tls = {
        termination = "edge"
      }
    }
  }
}

