#!/bin/bash
# ROSA Cleanup Script
# Safely deletes ROSA cluster and associated resources

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

CLUSTER_NAME="${1:-}"
ENVIRONMENT="${2:-prod}"
FORCE_DELETE="${3:-false}"
AWS_REGION="${4:-us-east-1}"

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPTS_DIR")"
TERRAFORM_DIR="terraform/environments/${ENVIRONMENT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
    if [[ "$FORCE_DELETE" == "true" ]]; then
        return 0
    fi
    
    read -p "$(echo -e "${YELLOW}$1 (y/N): ${NC}")" -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

show_usage() {
    echo "Usage: $0 CLUSTER_NAME [ENVIRONMENT] [FORCE_DELETE] [AWS_REGION]"
    echo
    echo "Arguments:"
    echo "  CLUSTER_NAME  Name of the ROSA cluster to delete (required)"
    echo "  ENVIRONMENT   Environment (default: prod)"
    echo "  FORCE_DELETE  Skip confirmation prompts (default: false)"
    echo "  AWS_REGION    AWS region (default: us-east-1)"
    echo
    echo "Examples:"
    echo "  $0 my-rosa-cluster                    # Delete cluster with prompts"
    echo "  $0 my-rosa-cluster prod true          # Force delete without prompts"
    echo "  $0 my-rosa-cluster staging false us-west-2  # Delete staging cluster in us-west-2"
    echo
    echo "WARNING: This script will permanently delete the specified ROSA cluster"
    echo "and all associated data. This action cannot be undone."
    exit 1
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_prerequisites() {
    log "🔍 Validating prerequisites..."
    
    # Check required tools
    local tools=("rosa" "aws" "terraform" "jq")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is not installed or not in PATH"
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured or invalid"
    fi
    
    # Check ROSA login
    if ! rosa whoami &> /dev/null; then
        error "Not logged into ROSA. Please run: rosa login"
    fi
    
    success "All prerequisites validated"
}

validate_cluster() {
    log "🔍 Validating cluster information..."
    
    if [[ -z "$CLUSTER_NAME" ]]; then
        error "Cluster name is required"
    fi
    
    # Check if cluster exists
    if ! rosa describe cluster --cluster="$CLUSTER_NAME" &> /dev/null; then
        error "Cluster '$CLUSTER_NAME' not found or not accessible"
    fi
    
    # Get cluster information
    local cluster_info
    cluster_info=$(rosa describe cluster --cluster="$CLUSTER_NAME" --output=json 2>/dev/null)
    
    local state region version
    state=$(echo "$cluster_info" | jq -r '.state // "unknown"')
    region=$(echo "$cluster_info" | jq -r '.region.id // "unknown"')
    version=$(echo "$cluster_info" | jq -r '.openshift_version // "unknown"')
    
    log "Cluster Information:"
    log "  Name: $CLUSTER_NAME"
    log "  State: $state"
    log "  Region: $region"
    log "  Version: $version"
    
    # Warn if cluster is not in a deletable state
    if [[ "$state" == "installing" ]] || [[ "$state" == "pending" ]]; then
        warning "Cluster is in '$state' state. Deletion may take longer or fail."
        if ! confirm "Do you want to continue with deletion?"; then
            error "Deletion cancelled by user"
        fi
    fi
    
    success "Cluster validation completed"
}

# =============================================================================
# BACKUP OPERATIONS
# =============================================================================

create_backup() {
    log "💾 Creating final backup before deletion..."
    
    local backup_dir="$PROJECT_ROOT/backups/$(date +%Y%m%d-%H%M%S)-$CLUSTER_NAME"
    mkdir -p "$backup_dir"
    
    # Save cluster information
    log "Saving cluster information..."
    rosa describe cluster --cluster="$CLUSTER_NAME" --output=json > "$backup_dir/cluster-info.json" 2>/dev/null || true
    rosa list operator-roles --cluster="$CLUSTER_NAME" --output=json > "$backup_dir/operator-roles.json" 2>/dev/null || true
    rosa list account-roles --output=json > "$backup_dir/account-roles.json" 2>/dev/null || true
    
    # Save recent logs
    log "Saving recent logs..."
    rosa logs install --cluster="$CLUSTER_NAME" --tail=100 > "$backup_dir/install-logs.txt" 2>/dev/null || true
    
    # Save Terraform state (if exists)
    if [[ -f "$PROJECT_ROOT/$TERRAFORM_DIR/terraform.tfstate" ]]; then
        log "Backing up Terraform state..."
        cp "$PROJECT_ROOT/$TERRAFORM_DIR/terraform.tfstate" "$backup_dir/" 2>/dev/null || true
    fi
    
    # Save configuration files
    if [[ -f "$PROJECT_ROOT/$TERRAFORM_DIR/terraform.tfvars" ]]; then
        log "Backing up Terraform configuration..."
        cp "$PROJECT_ROOT/$TERRAFORM_DIR/terraform.tfvars" "$backup_dir/" 2>/dev/null || true
    fi
    
    success "Backup created at: $backup_dir"
}

# =============================================================================
# DELETION OPERATIONS
# =============================================================================

delete_cluster_resources() {
    log "🗑️  Deleting cluster resources..."
    
    # Check if cluster has any persistent resources to warn about
    local cluster_info
    cluster_info=$(rosa describe cluster --cluster="$CLUSTER_NAME" --output=json 2>/dev/null || echo "{}")
    
    if [[ "$cluster_info" != "{}" ]]; then
        local load_balancers
        load_balancers=$(echo "$cluster_info" | jq -r '.load_balancers // [] | length')
        
        if [[ "$load_balancers" -gt 0 ]]; then
            warning "Cluster has $load_balancers load balancer(s) that will be deleted"
        fi
    fi
    
    # Delete the cluster
    log "Initiating cluster deletion..."
    if rosa delete cluster --cluster="$CLUSTER_NAME" --yes; then
        success "Cluster deletion initiated"
    else
        error "Failed to initiate cluster deletion"
    fi
    
    # Monitor deletion progress
    monitor_deletion
}

monitor_deletion() {
    log "⏳ Monitoring cluster deletion progress..."
    
    local timeout=3600  # 1 hour timeout
    local elapsed=0
    local check_interval=30
    
    while [[ $elapsed -lt $timeout ]]; do
        # Check if cluster still exists
        if ! rosa describe cluster --cluster="$CLUSTER_NAME" &> /dev/null; then
            success "Cluster has been completely deleted"
            return 0
        fi
        
        # Get current status
        local status
        status=$(rosa describe cluster --cluster="$CLUSTER_NAME" --output=json 2>/dev/null | jq -r '.state // "unknown"' || echo "deleting")
        
        case "$status" in
            "uninstalling"|"pending")
                log "Cluster deletion in progress: $status (${elapsed}s elapsed)"
                ;;
            "error"|"failed")
                error "Cluster deletion failed with status: $status"
                ;;
            *)
                log "Cluster status: $status"
                ;;
        esac
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    warning "Timeout waiting for cluster deletion to complete (${timeout}s)"
    warning "Cluster may still be deleting in the background"
}

delete_operator_roles() {
    log "🔐 Deleting operator roles..."
    
    # List operator roles for this cluster
    local operator_roles
    operator_roles=$(rosa list operator-roles --cluster="$CLUSTER_NAME" --output=json 2>/dev/null || echo "[]")
    
    if [[ "$operator_roles" == "[]" ]] || [[ $(echo "$operator_roles" | jq length) -eq 0 ]]; then
        log "No operator roles found for cluster $CLUSTER_NAME"
        return 0
    fi
    
    # Delete operator roles
    log "Found operator roles, attempting deletion..."
    if rosa delete operator-roles --cluster="$CLUSTER_NAME" --mode=auto --yes 2>/dev/null; then
        success "Operator roles deleted successfully"
    else
        warning "Failed to delete operator roles automatically"
        warning "You may need to delete them manually using: rosa delete operator-roles --cluster=$CLUSTER_NAME"
    fi
}

delete_oidc_provider() {
    log "🔐 Deleting OIDC provider..."
    
    # Try to delete OIDC provider
    if rosa delete oidc-provider --cluster="$CLUSTER_NAME" --mode=auto --yes 2>/dev/null; then
        success "OIDC provider deleted successfully"
    else
        warning "Failed to delete OIDC provider"
        warning "It may have been shared with other clusters or already deleted"
    fi
}

cleanup_terraform_state() {
    log "📝 Cleaning up Terraform state..."
    
    local tf_dir="$PROJECT_ROOT/$TERRAFORM_DIR"
    
    if [[ ! -d "$tf_dir" ]]; then
        warning "Terraform directory not found: $tf_dir"
        return 0
    fi
    
    cd "$tf_dir"
    
    # Check if Terraform state exists
    if [[ ! -f "terraform.tfstate" ]]; then
        log "No Terraform state file found"
        return 0
    fi
    
    # Run terraform destroy to clean up remaining resources
    if confirm "Do you want to run 'terraform destroy' to clean up remaining infrastructure?"; then
        log "Running terraform destroy..."
        if terraform destroy -auto-approve; then
            success "Terraform destroy completed successfully"
        else
            warning "Terraform destroy encountered errors"
            warning "Some resources may need manual cleanup"
        fi
    else
        warning "Skipping terraform destroy"
        warning "You may want to run 'terraform destroy' manually later"
    fi
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# POST-DELETION CLEANUP
# =============================================================================

verify_deletion() {
    log "🔍 Verifying complete deletion..."
    
    # Check if cluster still exists
    if rosa describe cluster --cluster="$CLUSTER_NAME" &> /dev/null; then
        warning "Cluster still exists - deletion may not be complete"
        return 1
    fi
    
    # Check for remaining operator roles
    local remaining_roles
    remaining_roles=$(rosa list operator-roles --cluster="$CLUSTER_NAME" --output=json 2>/dev/null | jq length 2>/dev/null || echo "0")
    
    if [[ "$remaining_roles" -gt 0 ]]; then
        warning "$remaining_roles operator role(s) still exist for cluster $CLUSTER_NAME"
        warning "Consider running: rosa delete operator-roles --cluster=$CLUSTER_NAME"
    fi
    
    success "Cluster deletion verification completed"
}

cleanup_local_files() {
    log "🧹 Cleaning up local files..."
    
    local tf_dir="$PROJECT_ROOT/$TERRAFORM_DIR"
    
    if confirm "Do you want to clean up local Terraform files (.terraform, *.tfplan, etc.)?"; then
        if [[ -d "$tf_dir" ]]; then
            cd "$tf_dir"
            
            # Remove Terraform working directory
            if [[ -d ".terraform" ]]; then
                rm -rf .terraform
                success "Removed .terraform directory"
            fi
            
            # Remove plan files
            if ls *.tfplan &> /dev/null; then
                rm -f *.tfplan
                success "Removed Terraform plan files"
            fi
            
            # Remove lock file
            if [[ -f ".terraform.lock.hcl" ]]; then
                rm -f .terraform.lock.hcl
                success "Removed Terraform lock file"
            fi
            
            cd "$PROJECT_ROOT"
        fi
    fi
    
    # Clean up output directories
    if [[ -d "rosa-outputs" ]] && confirm "Do you want to remove the rosa-outputs directory?"; then
        rm -rf rosa-outputs
        success "Removed rosa-outputs directory"
    fi
}

# =============================================================================
# MAIN DELETION WORKFLOW
# =============================================================================

main() {
    if [[ -z "$CLUSTER_NAME" ]]; then
        show_usage
    fi
    
    log "🗑️  Starting ROSA cluster deletion process"
    log "Cluster: $CLUSTER_NAME"
    log "Environment: $ENVIRONMENT"
    log "Region: $AWS_REGION"
    log "Force mode: $FORCE_DELETE"
    echo
    
    # Final confirmation
    if ! confirm "Are you sure you want to delete cluster '$CLUSTER_NAME'? This action cannot be undone!"; then
        log "Deletion cancelled by user"
        exit 0
    fi
    
    # Validate prerequisites
    validate_prerequisites
    
    # Validate cluster
    validate_cluster
    
    # Create backup
    if confirm "Do you want to create a backup before deletion?"; then
        create_backup
    fi
    
    # Delete cluster and resources
    delete_cluster_resources
    
    # Clean up operator roles
    delete_operator_roles
    
    # Clean up OIDC provider
    delete_oidc_provider
    
    # Clean up Terraform state
    cleanup_terraform_state
    
    # Verify deletion
    verify_deletion
    
    # Clean up local files
    cleanup_local_files
    
    success "🎉 ROSA cluster deletion completed!"
    
    # Show summary
    echo
    echo "==================================="
    echo "DELETION SUMMARY"
    echo "==================================="
    echo "Cluster '$CLUSTER_NAME' has been deleted"
    echo "Associated operator roles cleaned up"
    echo "OIDC provider cleaned up"
    echo "Local files cleaned up (if selected)"
    echo
    echo "Manual cleanup may be required for:"
    echo "- AWS resources created outside of ROSA/Terraform"
    echo "- S3 buckets with versioning enabled"
    echo "- CloudWatch log groups (if retention enabled)"
    echo "- Route53 hosted zones (if created)"
    echo "==================================="
}

# Show usage if help requested
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    show_usage
fi

# Run main function
main "$@"