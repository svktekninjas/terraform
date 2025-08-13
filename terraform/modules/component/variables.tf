variable "namespace" {
  description = "Application namesapce"
  type        = string
}

variable "dockerconfigjson_base64" {
  description = "Base64 encoded dockerconfigjson secret for ECR"
  type        = string
}
