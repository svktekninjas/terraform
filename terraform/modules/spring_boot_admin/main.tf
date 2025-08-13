resource "kubernetes_service" "app_svc" {
  metadata {
    name      = "spring-boot-admin-new"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "spring-boot-admin-new"
    }

    port {
      port        = 8082
      target_port = 8082
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_deployment" "app_deploy" {
  metadata {
    name      = "spring-boot-admin-new"
    namespace = var.namespace
    labels = {
      app = "spring-boot-admin-new"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "spring-boot-admin-new"
      }
    }

    template {
      metadata {
        labels = {
          app = "spring-boot-admin-new"
        }
      }

      spec {
        image_pull_secrets {
          name = "ecr-secret"
        }

        container {
          name  = "spring-boot-admin-new"
          image = var.image

          port {
            container_port = 8082
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
      name      = "spring-boot-admin-new"
      namespace = var.namespace
    }
    spec = {
      to = {
        kind = "Service"
        name = kubernetes_service.app_svc.metadata[0].name
      }
      port = {
        targetPort = "8082"
      }
      tls = {
        termination = "edge"
      }
    }
  }
}

