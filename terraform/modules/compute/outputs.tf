# Outputs for Compute Module

output "rosa_create_cluster_command" {
  description = "ROSA CLI command used to create the cluster"
  value       = local.rosa_create_cluster_cmd
}

output "rosa_create_admin_command" {
  description = "ROSA CLI command used to create admin user"
  value       = local.rosa_create_admin_cmd
}

output "cluster_creation_status" {
  description = "Status of cluster creation"
  value       = try(null_resource.rosa_cluster.id != null ? "Cluster creation initiated" : "Not created", "Unknown")
}

output "admin_user_creation_status" {
  description = "Status of admin user creation"
  value       = var.create_admin_user ? try(null_resource.rosa_admin_user[0].id != null ? "Admin user created" : "Not created", "Unknown") : "Skipped"
}

output "cluster_name" {
  description = "Name of the created ROSA cluster"
  value       = var.cluster_name
}

output "cluster_region" {
  description = "AWS region where cluster is deployed"
  value       = var.aws_region
}

output "openshift_version" {
  description = "OpenShift version of the cluster"
  value       = var.openshift_version
}

output "cluster_info_saved" {
  description = "Whether cluster information was saved to files"
  value       = var.save_cluster_info ? "Yes, check ${var.output_dir}/" : "No"
}