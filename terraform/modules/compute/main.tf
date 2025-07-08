# Compute Module for ROSA CLI Integration
# Executes ROSA CLI commands to create and manage the cluster

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  # Construct ROSA CLI create cluster command
  rosa_create_cluster_cmd = join(" ", compact([
    "rosa create cluster",
    "--cluster-name=${var.cluster_name}",
    "--region=${var.aws_region}",
    "--version=${var.openshift_version}",
    "--compute-machine-type=${var.compute_machine_type}",
    length(var.subnet_ids) > 0 ? "--subnet-ids=${join(",", var.subnet_ids)}" : "",
    length(var.availability_zones) > 0 ? "--availability-zones=${join(",", var.availability_zones)}" : "",
    var.enable_autoscaling ? "--enable-autoscaling" : "--replicas=${var.compute_nodes}",
    var.enable_autoscaling ? "--min-replicas=${var.min_replicas}" : "",
    var.enable_autoscaling ? "--max-replicas=${var.max_replicas}" : "",
    var.multi_az ? "--multi-az" : "",
    var.enable_sts ? "--sts" : "",
    var.enable_fips ? "--fips" : "",
    var.enable_etcd_encryption ? "--etcd-encryption" : "",
    var.private ? "--private" : "",
    var.private_link ? "--private-link" : "",
    var.disable_user_workload_monitoring ? "--disable-user-workload-monitoring" : "",
    var.host_prefix != 23 ? "--host-prefix=${var.host_prefix}" : "",
    var.machine_cidr != "" ? "--machine-cidr=${var.machine_cidr}" : "",
    var.service_cidr != "" ? "--service-cidr=${var.service_cidr}" : "",
    var.pod_cidr != "" ? "--pod-cidr=${var.pod_cidr}" : "",
    var.kms_key_arn != "" ? "--kms-key-arn=${var.kms_key_arn}" : "",
    var.role_arn != "" ? "--role-arn=${var.role_arn}" : "",
    var.support_role_arn != "" ? "--support-role-arn=${var.support_role_arn}" : "",
    var.operator_roles_prefix != "" ? "--operator-roles-prefix=${var.operator_roles_prefix}" : "",
    var.oidc_config_id != "" ? "--oidc-config-id=${var.oidc_config_id}" : "",
    var.disable_scp_checks ? "--disable-scp-checks" : "",
    var.enable_proxy ? "--http-proxy=${var.http_proxy}" : "",
    var.enable_proxy ? "--https-proxy=${var.https_proxy}" : "",
    var.enable_proxy && var.no_proxy != "" ? "--no-proxy=${var.no_proxy}" : "",
    var.additional_trust_bundle != "" ? "--additional-trust-bundle=${var.additional_trust_bundle}" : "",
    "--tags=${join(",", [for k, v in var.tags : "${k}=${v}"])}",
    "--mode=${var.mode}",
    var.dry_run ? "--dry-run" : "",
    var.watch ? "--watch" : "",
    "--yes"
  ]))
  
  # ROSA CLI create admin command
  rosa_create_admin_cmd = var.create_admin_user ? join(" ", compact([
    "rosa create admin",
    "--cluster=${var.cluster_name}",
    var.admin_username != "" ? "--username=${var.admin_username}" : "",
    var.admin_password != "" ? "--password=${var.admin_password}" : ""
  ])) : ""
  
  # Create account roles command (if STS enabled)
  rosa_create_account_roles_cmd = var.enable_sts && var.auto_create_roles ? join(" ", compact([
    "rosa create account-roles",
    "--mode=auto",
    "--yes"
  ])) : ""
  
  # Create operator roles command (if STS enabled)
  rosa_create_operator_roles_cmd = var.enable_sts && var.auto_create_roles ? join(" ", compact([
    "rosa create operator-roles",
    "--cluster=${var.cluster_name}",
    "--mode=auto",
    "--yes"
  ])) : ""
  
  # Create OIDC provider command (if STS enabled)
  rosa_create_oidc_provider_cmd = var.enable_sts && var.auto_create_roles && var.oidc_config_id == "" ? join(" ", compact([
    "rosa create oidc-provider",
    "--cluster=${var.cluster_name}",
    "--mode=auto",
    "--yes"
  ])) : ""
}

# =============================================================================
# ROSA STS PREREQUISITES (if enabled)
# =============================================================================

# Create account roles (if STS enabled and auto-create is true)
resource "null_resource" "rosa_account_roles" {
  count = var.enable_sts && var.auto_create_roles ? 1 : 0
  
  provisioner "local-exec" {
    command = local.rosa_create_account_roles_cmd
  }
  
  # Trigger recreation if cluster name changes
  triggers = {
    cluster_name = var.cluster_name
  }
}

# Create OIDC provider (if STS enabled and no existing OIDC config)
resource "null_resource" "rosa_oidc_provider" {
  count = var.enable_sts && var.auto_create_roles && var.oidc_config_id == "" ? 1 : 0
  
  depends_on = [null_resource.rosa_account_roles]
  
  provisioner "local-exec" {
    command = local.rosa_create_oidc_provider_cmd
  }
  
  triggers = {
    cluster_name = var.cluster_name
  }
}

# =============================================================================
# ROSA CLUSTER CREATION
# =============================================================================

resource "null_resource" "rosa_cluster" {
  depends_on = [
    null_resource.rosa_account_roles,
    null_resource.rosa_oidc_provider
  ]
  
  # Trigger recreation on cluster configuration changes
  triggers = {
    cluster_name         = var.cluster_name
    compute_machine_type = var.compute_machine_type
    openshift_version    = var.openshift_version
    compute_nodes        = var.compute_nodes
    enable_autoscaling   = var.enable_autoscaling
    min_replicas         = var.min_replicas
    max_replicas         = var.max_replicas
    multi_az             = var.multi_az
    enable_sts           = var.enable_sts
    enable_fips          = var.enable_fips
    enable_etcd_encryption = var.enable_etcd_encryption
    private              = var.private
    private_link         = var.private_link
    subnet_ids           = join(",", var.subnet_ids)
    kms_key_arn          = var.kms_key_arn
    rosa_config_hash     = sha256(local.rosa_create_cluster_cmd)
  }
  
  # Create ROSA cluster
  provisioner "local-exec" {
    command = local.rosa_create_cluster_cmd
  }
  
  # Delete cluster on destroy
  provisioner "local-exec" {
    when    = destroy
    command = "rosa delete cluster --cluster=${self.triggers.cluster_name} --yes || true"
  }
}

# =============================================================================
# ROSA OPERATOR ROLES (post-cluster creation for STS)
# =============================================================================

resource "null_resource" "rosa_operator_roles" {
  count = var.enable_sts && var.auto_create_roles ? 1 : 0
  
  depends_on = [null_resource.rosa_cluster]
  
  provisioner "local-exec" {
    command = local.rosa_create_operator_roles_cmd
  }
  
  triggers = {
    cluster_name = var.cluster_name
  }
}

# =============================================================================
# ROSA ADMIN USER CREATION
# =============================================================================

resource "null_resource" "rosa_admin_user" {
  count = var.create_admin_user ? 1 : 0
  
  depends_on = [
    null_resource.rosa_cluster,
    null_resource.rosa_operator_roles
  ]
  
  provisioner "local-exec" {
    command = local.rosa_create_admin_cmd
  }
  
  triggers = {
    cluster_name    = var.cluster_name
    admin_username  = var.admin_username
    admin_password  = var.admin_password
  }
}

# =============================================================================
# CLUSTER INFO COLLECTION
# =============================================================================

resource "null_resource" "rosa_cluster_info" {
  count = var.save_cluster_info ? 1 : 0
  
  depends_on = [
    null_resource.rosa_cluster,
    null_resource.rosa_admin_user
  ]
  
  provisioner "local-exec" {
    command = join(" && ", [
      "mkdir -p ${var.output_dir}",
      "rosa describe cluster --cluster=${var.cluster_name} --output=json > ${var.output_dir}/cluster-info.json || true",
      "rosa list operator-roles --cluster=${var.cluster_name} --output=json > ${var.output_dir}/operator-roles.json || true",
      "rosa list account-roles --output=json > ${var.output_dir}/account-roles.json || true",
      var.enable_sts ? "rosa describe oidc-provider --cluster=${var.cluster_name} --output=json > ${var.output_dir}/oidc-provider.json || true" : "echo 'STS not enabled' > ${var.output_dir}/oidc-provider.json",
      "rosa logs install --cluster=${var.cluster_name} --tail=50 > ${var.output_dir}/install-logs.txt || true"
    ])
  }
  
  triggers = {
    cluster_name = var.cluster_name
    timestamp    = timestamp()
  }
}