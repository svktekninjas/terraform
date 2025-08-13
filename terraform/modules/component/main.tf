terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.37.1"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "app_ns" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret" "ecr_secret" {
  metadata {
    name      = "ecr-secret"
    namespace = var.namespace
  }

  data = {
    ".dockerconfigjson" = base64decode(var.dockerconfigjson_base64)
  }

  type = "kubernetes.io/dockerconfigjson"
}

