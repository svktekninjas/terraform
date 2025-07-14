#!/bin/bash
# Development Environment Export Script
# Sets environment-specific variables for ROSA pre-validation

# =============================================================================
# AWS CONFIGURATION
# =============================================================================

# Set AWS profile and region
export AWS_PROFILE="svktek"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_REGION="us-east-1"

# =============================================================================
# ENVIRONMENT CONFIGURATION
# =============================================================================

# Set environment variables
export ENVIRONMENT="dev"
export TERRAFORM_WORKSPACE="dev"

# =============================================================================
# PROJECT CONFIGURATION
# =============================================================================

# Set project variables
export PROJECT_NAME="ROSA-Infrastructure"
export PROJECT_VERSION="1.0.0"

# =============================================================================
# TERRAFORM VARIABLES
# =============================================================================

# Core Terraform variables
export TF_VAR_environment="dev"
export TF_VAR_aws_region="us-east-1"
export TF_VAR_cluster_name="rosa-cluster"
export TF_VAR_openshift_version="4.14"

# Dev-specific Terraform variables
export TF_VAR_compute_machine_type="m5.large"
export TF_VAR_enable_autoscaling="true"
export TF_VAR_min_replicas="2"
export TF_VAR_max_replicas="5"
export TF_VAR_owner="DevTeam"

# Validation control variables
export TF_VAR_enable_pre_validation="true"
export TF_VAR_enable_quota_validation="true"
export TF_VAR_enable_rosa_validation="true"
export TF_VAR_verify_rosa_quota="false"  # Optional for dev

# =============================================================================
# DEV ENVIRONMENT CUSTOMIZATIONS
# =============================================================================

# Cost optimization flags
export DEV_COST_OPTIMIZED="true"
export DEV_SINGLE_AZ="false"  # Still use 2 AZs for dev
export DEV_RELAXED_VALIDATION="true"

# Development features
export DEV_ENABLE_DEBUG="true"
export DEV_FASTER_DEPLOYMENT="true"
export DEV_ALLOW_EXPERIMENTAL="true"

# =============================================================================
# LOGGING AND OUTPUT
# =============================================================================

echo "=================================================="
echo "ROSA Development Environment Variables Set"
echo "=================================================="
echo "Environment: $ENVIRONMENT"
echo "AWS Region: $AWS_REGION"
echo "AWS Profile: $AWS_PROFILE"
echo "Terraform workspace: $TERRAFORM_WORKSPACE"
echo "Cluster name: $TF_VAR_cluster_name-$ENVIRONMENT"
echo "Instance type: $TF_VAR_compute_machine_type"
echo "Replicas: $TF_VAR_min_replicas-$TF_VAR_max_replicas"
echo "Cost optimized: $DEV_COST_OPTIMIZED"
echo "Debug enabled: $DEV_ENABLE_DEBUG"
echo "=================================================="
echo "Ready for pre-validation execution:"
echo "  terraform plan -target=module.pre_validation"
echo "  terraform apply -target=module.pre_validation"
echo "=================================================="
