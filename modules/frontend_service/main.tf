resource "kubernetes_service" "app_svc" {
  metadata {
    name      = "frontend-service"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "bench-profile-service-new"
    }

    port {
      port        = 3000
      target_port = 3000
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_deployment" "app_deploy" {
  metadata {
    name      = "frontend-service"
    namespace = var.namespace
    labels = {
      app = "frontend-service"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "frontend-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend-service"
        }
      }

      spec {
        image_pull_secrets {
          name = "ecr-secret"
        }

        container {
          name  = "frontend-service"
          image = var.image

          port {
            container_port = 3000
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
      name      = "frontend-service"
      namespace = var.namespace
    }
    spec = {
      to = {
        kind = "Service"
        name = kubernetes_service.app_svc.metadata[0].name
      }
      port = {
        targetPort = "3000"
      }
      tls = {
        termination = "edge"
      }
    }
  }
}

