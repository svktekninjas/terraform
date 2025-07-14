#!/bin/bash
# ROSA Validation Phases Execution Script
# This script helps execute validation phases in sequence

set -e

ENVIRONMENT="${1:-prod}"
ACTION="${2:-apply}"
PHASE="${3:-all}"

if [ "$ENVIRONMENT" = "-h" ] || [ "$ENVIRONMENT" = "--help" ]; then
    echo "Usage: $0 [environment] [action] [phase]"
    echo ""
    echo "Arguments:"
    echo "  environment: dev, staging, or prod (default: prod)"
    echo "  action: plan or apply (default: apply)"
    echo "  phase: pre, infra, post, or all (default: all)"
    echo ""
    echo "Examples:"
    echo "  $0 prod plan pre      # Plan pre-validation for production"
    echo "  $0 dev apply infra    # Apply infra-validation for development"
    echo "  $0 staging apply all  # Apply all phases sequentially for staging"
    exit 0
fi

ENV_DIR="environments/${ENVIRONMENT}"

if [ ! -d "$ENV_DIR" ]; then
    echo "Error: Environment directory '$ENV_DIR' not found"
    echo "Available environments: dev, staging, prod"
    exit 1
fi

echo "====================================="
echo "ROSA Validation Phases Execution"
echo "Environment: $ENVIRONMENT"
echo "Action: $ACTION"
echo "Phase: $PHASE"
echo "====================================="

cd "$ENV_DIR"

run_pre_validation() {
    echo ""
    echo "🔍 Running PRE-VALIDATION phase..."
    echo "Validating: Region, AZs, Config, Quotas, ROSA CLI"
    
    terraform $ACTION \
        -var="enable_pre_validation=true" \
        -var="enable_infra_validation=false" \
        -var="enable_post_validation=false" \
        -target="module.validation"
}

run_infra_creation() {
    echo ""
    echo "🏗️  Creating infrastructure..."
    echo "Creating: Networking, Security, Storage"
    
    terraform $ACTION \
        -target="module.networking" \
        -target="module.security" \
        -target="module.storage"
}

run_infra_validation() {
    echo ""
    echo "🔍 Running INFRA-VALIDATION phase..."
    echo "Validating: VPC, Subnets, Networking, Proxy"
    
    terraform $ACTION \
        -var="enable_pre_validation=false" \
        -var="enable_infra_validation=true" \
        -var="enable_post_validation=false" \
        -target="module.validation"
}

run_cluster_creation() {
    echo ""
    echo "🚀 Creating ROSA cluster..."
    echo "Creating: Compute, Monitoring, Backup"
    
    terraform $ACTION \
        -target="module.compute" \
        -target="module.monitoring" \
        -target="module.backup"
}

run_post_validation() {
    echo ""
    echo "🔍 Running POST-VALIDATION phase..."
    echo "Validating: Cluster readiness, Components"
    
    terraform $ACTION \
        -var="enable_pre_validation=false" \
        -var="enable_infra_validation=false" \
        -var="enable_post_validation=true" \
        -target="module.validation"
}

case "$PHASE" in
    "pre")
        run_pre_validation
        ;;
    "infra")
        run_infra_creation
        run_infra_validation
        ;;
    "post")
        run_cluster_creation
        run_post_validation
        ;;
    "all")
        echo "Running all validation phases sequentially..."
        run_pre_validation
        
        if [ $? -eq 0 ]; then
            run_infra_creation
            if [ $? -eq 0 ]; then
                run_infra_validation
                if [ $? -eq 0 ]; then
                    run_cluster_creation
                    if [ $? -eq 0 ]; then
                        run_post_validation
                    else
                        echo "❌ Cluster creation failed"
                        exit 1
                    fi
                else
                    echo "❌ Infrastructure validation failed"
                    exit 1
                fi
            else
                echo "❌ Infrastructure creation failed"
                exit 1
            fi
        else
            echo "❌ Pre-validation failed"
            exit 1
        fi
        ;;
    *)
        echo "Error: Invalid phase '$PHASE'"
        echo "Valid phases: pre, infra, post, all"
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Phase '$PHASE' completed successfully!"
else
    echo ""
    echo "❌ Phase '$PHASE' failed!"
    exit 1
fi