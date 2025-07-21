resource "kubernetes_service" "app_svc" {
  metadata {
    name      = "naming-server-new"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "naming-server-new"
    }

    port {
      port        = 8761
      target_port = 8761
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_deployment" "app_deploy" {
  metadata {
    name      = "naming-server-new"
    namespace = var.namespace
    labels = {
      app = "naming-server-new"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "naming-server-new"
      }
    }

    template {
      metadata {
        labels = {
          app = "naming-server-new"
        }
      }

      spec {
        image_pull_secrets {
          name = "ecr-secret"
        }

        container {
          name  = "naming-server-new"
          image = var.image

          port {
            container_port = 8761
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
      name      = "naming-server-new"
      namespace = var.namespace
    }
    spec = {
      to = {
        kind = "Service"
        name = kubernetes_service.app_svc.metadata[0].name
      }
      port = {
        targetPort = "8761"
      }
      tls = {
        termination = "edge"
      }
    }
  }
}

