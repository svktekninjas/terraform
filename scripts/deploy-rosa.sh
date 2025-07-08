#!/bin/bash
# ROSA Deployment Automation Script
# Deploys ROSA cluster using Terraform with validation and monitoring

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Default values
ENVIRONMENT="${1:-prod}"
CLUSTER_NAME="${2:-rosa-${ENVIRONMENT}-cluster}"
AWS_REGION="${3:-us-east-1}"
TERRAFORM_DIR="terraform/environments/${ENVIRONMENT}"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPTS_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

confirm() {
    read -p "$(echo -e "${YELLOW}$1 (y/N): ${NC}")" -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# =============================================================================
# PREREQUISITE VALIDATION
# =============================================================================

validate_prerequisites() {
    log "🔍 Validating prerequisites..."
    
    # Check if running in correct directory
    if [[ ! -f "${PROJECT_ROOT}/terraform/variables.tf" ]]; then
        error "Please run this script from the project root directory"
    fi
    
    # Check required tools
    local tools=("terraform" "aws" "rosa" "jq")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is not installed or not in PATH"
        fi
    done
    
    # Check tool versions
    log "Checking tool versions..."
    terraform version | head -n1
    aws --version
    rosa version
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured or invalid"
    fi
    
    # Check ROSA login
    if ! rosa whoami &> /dev/null; then
        warning "Not logged into ROSA. Please run: rosa login"
        if confirm "Do you want to continue anyway?"; then
            log "Continuing without ROSA login verification..."
        else
            error "Please login to ROSA first: rosa login"
        fi
    fi
    
    success "All prerequisites validated"
}

# =============================================================================
# TERRAFORM OPERATIONS
# =============================================================================

terraform_init() {
    log "🚀 Initializing Terraform..."
    
    cd "${PROJECT_ROOT}/${TERRAFORM_DIR}"
    
    # Initialize Terraform
    terraform init -upgrade
    
    # Validate configuration
    terraform validate
    
    success "Terraform initialized and validated"
}

terraform_plan() {
    log "📋 Creating Terraform plan..."
    
    cd "${PROJECT_ROOT}/${TERRAFORM_DIR}"
    
    # Create plan
    terraform plan \
        -var="cluster_name=${CLUSTER_NAME}" \
        -var="aws_region=${AWS_REGION}" \
        -out="terraform.tfplan"
    
    success "Terraform plan created"
}

terraform_apply() {
    log "🏗️  Applying Terraform configuration..."
    
    cd "${PROJECT_ROOT}/${TERRAFORM_DIR}"
    
    # Apply the plan
    terraform apply "terraform.tfplan"
    
    success "Terraform configuration applied"
}

# =============================================================================
# ROSA OPERATIONS
# =============================================================================

verify_rosa_readiness() {
    log "🔍 Verifying ROSA readiness..."
    
    # Verify ROSA quota
    log "Checking ROSA quota..."
    rosa verify quota --region="$AWS_REGION"
    
    # Verify AWS permissions
    log "Checking AWS permissions..."
    rosa verify permissions
    
    success "ROSA environment is ready"
}

monitor_cluster_creation() {
    log "⏳ Monitoring cluster creation progress..."
    
    local timeout=3600  # 1 hour timeout
    local elapsed=0
    local check_interval=60
    
    while [[ $elapsed -lt $timeout ]]; do
        local status
        status=$(rosa describe cluster --cluster="$CLUSTER_NAME" --output=json 2>/dev/null | jq -r '.state // "unknown"' || echo "unknown")
        
        case "$status" in
            "ready")
                success "Cluster is ready!"
                return 0
                ;;
            "error"|"failed")
                error "Cluster creation failed with status: $status"
                ;;
            "installing"|"pending"|"validating")
                log "Cluster status: $status (${elapsed}s elapsed)"
                ;;
            "unknown")
                warning "Unable to get cluster status. Cluster may not exist yet."
                ;;
            *)
                log "Cluster status: $status"
                ;;
        esac
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    error "Timeout waiting for cluster to be ready (${timeout}s)"
}

get_cluster_info() {
    log "📊 Retrieving cluster information..."
    
    # Get cluster details
    local cluster_info
    cluster_info=$(rosa describe cluster --cluster="$CLUSTER_NAME" --output=json 2>/dev/null || echo "{}")
    
    if [[ "$cluster_info" == "{}" ]]; then
        warning "Unable to retrieve cluster information"
        return 1
    fi
    
    # Extract key information
    local api_url console_url version state
    api_url=$(echo "$cluster_info" | jq -r '.api.url // "N/A"')
    console_url=$(echo "$cluster_info" | jq -r '.console.url // "N/A"')
    version=$(echo "$cluster_info" | jq -r '.openshift_version // "N/A"')
    state=$(echo "$cluster_info" | jq -r '.state // "N/A"')
    
    # Display information
    echo
    echo "==================================="
    echo "CLUSTER INFORMATION"
    echo "==================================="
    echo "Cluster Name: $CLUSTER_NAME"
    echo "State: $state"
    echo "Version: $version"
    echo "API URL: $api_url"
    echo "Console URL: $console_url"
    echo "Region: $AWS_REGION"
    echo "==================================="
    echo
    
    success "Cluster information retrieved"
}

create_admin_user() {
    log "👤 Creating cluster admin user..."
    
    # Check if admin user already exists
    if rosa list users --cluster="$CLUSTER_NAME" 2>/dev/null | grep -q "cluster-admin"; then
        warning "Admin user already exists"
        return 0
    fi
    
    # Create admin user
    rosa create admin --cluster="$CLUSTER_NAME"
    
    success "Admin user created"
}

# =============================================================================
# POST-DEPLOYMENT VALIDATION
# =============================================================================

validate_deployment() {
    log "✅ Validating deployment..."
    
    # Check cluster status
    local status
    status=$(rosa describe cluster --cluster="$CLUSTER_NAME" --output=json 2>/dev/null | jq -r '.state // "unknown"')
    
    if [[ "$status" != "ready" ]]; then
        error "Cluster is not in ready state: $status"
    fi
    
    # Check node count
    local node_count
    node_count=$(rosa describe cluster --cluster="$CLUSTER_NAME" --output=json 2>/dev/null | jq -r '.nodes.compute // 0')
    
    if [[ "$node_count" -lt 2 ]]; then
        error "Insufficient worker nodes: $node_count (minimum: 2)"
    fi
    
    # Check operators
    log "Checking cluster operators..."
    rosa list operator-roles --cluster="$CLUSTER_NAME" --output=json >/dev/null
    
    success "Deployment validation completed"
}

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        error "Script failed with exit code $exit_code"
        
        if confirm "Do you want to view recent installation logs?"; then
            rosa logs install --cluster="$CLUSTER_NAME" --tail=50 || true
        fi
        
        if confirm "Do you want to delete the failed cluster?"; then
            rosa delete cluster --cluster="$CLUSTER_NAME" --yes || true
        fi
    fi
}

# =============================================================================
# MAIN DEPLOYMENT WORKFLOW
# =============================================================================

main() {
    log "🚀 Starting ROSA deployment for environment: $ENVIRONMENT"
    log "Cluster name: $CLUSTER_NAME"
    log "AWS region: $AWS_REGION"
    
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Validate prerequisites
    validate_prerequisites
    
    # Verify ROSA readiness
    verify_rosa_readiness
    
    # Terraform operations
    terraform_init
    terraform_plan
    
    # Confirm before applying
    if ! confirm "Do you want to proceed with the deployment?"; then
        log "Deployment cancelled by user"
        exit 0
    fi
    
    terraform_apply
    
    # Monitor cluster creation
    monitor_cluster_creation
    
    # Get cluster information
    get_cluster_info
    
    # Create admin user
    create_admin_user
    
    # Validate deployment
    validate_deployment
    
    success "🎉 ROSA deployment completed successfully!"
    
    # Show next steps
    echo
    echo "==================================="
    echo "NEXT STEPS"
    echo "==================================="
    echo "1. Access your cluster:"
    echo "   rosa describe cluster --cluster=$CLUSTER_NAME"
    echo
    echo "2. Get admin credentials:"
    echo "   rosa list users --cluster=$CLUSTER_NAME"
    echo
    echo "3. Access the console:"
    echo "   Open the Console URL shown above"
    echo
    echo "4. Configure kubectl:"
    echo "   rosa create admin --cluster=$CLUSTER_NAME"
    echo "   # Follow the instructions to configure kubectl"
    echo
    echo "5. Monitor your cluster:"
    echo "   Check CloudWatch dashboard (URL in Terraform outputs)"
    echo "==================================="
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Show usage if help requested
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [ENVIRONMENT] [CLUSTER_NAME] [AWS_REGION]"
    echo
    echo "Arguments:"
    echo "  ENVIRONMENT  Environment to deploy (default: prod)"
    echo "  CLUSTER_NAME Cluster name (default: rosa-ENVIRONMENT-cluster)"
    echo "  AWS_REGION   AWS region (default: us-east-1)"
    echo
    echo "Examples:"
    echo "  $0                           # Deploy prod environment with defaults"
    echo "  $0 staging                   # Deploy staging environment"
    echo "  $0 prod my-cluster us-west-2 # Deploy prod with custom name and region"
    echo
    exit 0
fi

# Run main function
main "$@"