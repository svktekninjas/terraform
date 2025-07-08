#!/bin/bash
# ROSA Validation Script
# Validates prerequisites and environment before deployment

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

ENVIRONMENT="${1:-prod}"
AWS_REGION="${2:-us-east-1}"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPTS_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Validation results
VALIDATION_PASSED=true
VALIDATION_RESULTS=()

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    VALIDATION_RESULTS+=("✅ $1")
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    VALIDATION_RESULTS+=("⚠️  $1")
}

error() {
    echo -e "${RED}❌ $1${NC}"
    VALIDATION_RESULTS+=("❌ $1")
    VALIDATION_PASSED=false
}

check_command() {
    local cmd="$1"
    local version_flag="${2:---version}"
    
    if command -v "$cmd" &> /dev/null; then
        local version
        version=$($cmd $version_flag 2>&1 | head -n1 || echo "Unknown version")
        success "$cmd is installed: $version"
        return 0
    else
        error "$cmd is not installed or not in PATH"
        return 1
    fi
}

# =============================================================================
# SYSTEM VALIDATION
# =============================================================================

validate_system() {
    log "🖥️  Validating system requirements..."
    
    # Check operating system
    local os_name
    os_name=$(uname -s)
    case "$os_name" in
        Darwin)
            success "Operating System: macOS"
            ;;
        Linux)
            success "Operating System: Linux"
            ;;
        *)
            warning "Operating System: $os_name (may not be fully supported)"
            ;;
    esac
    
    # Check available disk space
    local available_space
    if command -v df &> /dev/null; then
        available_space=$(df -h . | awk 'NR==2 {print $4}')
        if [[ "$available_space" ]]; then
            success "Available disk space: $available_space"
        fi
    fi
    
    # Check memory
    if command -v free &> /dev/null; then
        local memory
        memory=$(free -h | awk 'NR==2{printf "%.1fGB", $2/1024/1024/1024}')
        success "Available memory: $memory"
    elif [[ "$os_name" == "Darwin" ]]; then
        local memory
        memory=$(system_profiler SPHardwareDataType | grep "Memory:" | awk '{print $2, $3}')
        success "Available memory: $memory"
    fi
}

# =============================================================================
# TOOL VALIDATION
# =============================================================================

validate_tools() {
    log "🔧 Validating required tools..."
    
    # Check Terraform
    if check_command "terraform" "version"; then
        local tf_version
        tf_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
        if [[ "$tf_version" != "unknown" ]]; then
            # Check if version is >= 1.0
            if printf '%s\n1.0.0\n' "$tf_version" | sort -V | head -n1 | grep -q "1.0.0"; then
                success "Terraform version $tf_version meets minimum requirement (>= 1.0.0)"
            else
                error "Terraform version $tf_version is below minimum requirement (>= 1.0.0)"
            fi
        fi
    fi
    
    # Check AWS CLI
    if check_command "aws" "--version"; then
        local aws_version
        aws_version=$(aws --version 2>&1 | awk '{print $1}' | cut -d'/' -f2)
        if [[ "$aws_version" ]]; then
            success "AWS CLI version: $aws_version"
        fi
    fi
    
    # Check ROSA CLI
    if check_command "rosa" "version"; then
        local rosa_version
        rosa_version=$(rosa version 2>/dev/null | head -n1 | awk '{print $2}' || echo "unknown")
        if [[ "$rosa_version" != "unknown" ]]; then
            success "ROSA CLI version: $rosa_version"
        fi
    fi
    
    # Check OpenShift CLI
    if check_command "oc" "version"; then
        local oc_version
        oc_version=$(oc version --client 2>/dev/null | grep "Client Version" | awk '{print $3}' || echo "unknown")
        if [[ "$oc_version" != "unknown" ]]; then
            success "OpenShift CLI version: $oc_version"
        fi
    else
        warning "OpenShift CLI (oc) not found - will be needed for cluster management"
    fi
    
    # Check jq
    check_command "jq" "--version"
    
    # Check git
    if check_command "git" "--version"; then
        success "Git is available for version control"
    else
        warning "Git not found - recommended for IaC version control"
    fi
}

# =============================================================================
# AWS VALIDATION
# =============================================================================

validate_aws() {
    log "☁️  Validating AWS configuration..."
    
    # Check AWS credentials
    if aws sts get-caller-identity &> /dev/null; then
        local account_id user_arn
        account_id=$(aws sts get-caller-identity --query Account --output text)
        user_arn=$(aws sts get-caller-identity --query Arn --output text)
        success "AWS credentials configured"
        success "Account ID: $account_id"
        success "User/Role: $user_arn"
    else
        error "AWS credentials not configured or invalid"
        return 1
    fi
    
    # Check AWS region
    local current_region
    current_region=$(aws configure get region 2>/dev/null || echo "not-set")
    if [[ "$current_region" == "not-set" ]]; then
        warning "AWS region not set in configuration"
        if [[ -n "${AWS_DEFAULT_REGION:-}" ]]; then
            success "AWS region from environment: $AWS_DEFAULT_REGION"
        else
            warning "No AWS region configured"
        fi
    else
        success "AWS region configured: $current_region"
    fi
    
    # Validate target region
    if aws ec2 describe-regions --region="$AWS_REGION" --query "Regions[?RegionName=='$AWS_REGION'].RegionName" --output text 2>/dev/null | grep -q "$AWS_REGION"; then
        success "Target region $AWS_REGION is valid and accessible"
    else
        error "Target region $AWS_REGION is not accessible or invalid"
    fi
    
    # Check availability zones
    local az_count
    az_count=$(aws ec2 describe-availability-zones --region="$AWS_REGION" --query "length(AvailabilityZones)" --output text 2>/dev/null || echo "0")
    if [[ "$az_count" -ge 3 ]]; then
        success "Target region has $az_count availability zones (minimum 3 required)"
    else
        error "Target region has only $az_count availability zones (minimum 3 required for ROSA)"
    fi
}

# =============================================================================
# AWS QUOTA VALIDATION
# =============================================================================

validate_aws_quotas() {
    log "📊 Validating AWS service quotas..."
    
    # Check EC2 vCPU limits
    local vcpu_limit
    vcpu_limit=$(aws service-quotas get-service-quota \
        --service-code ec2 \
        --quota-code L-34B43A08 \
        --region "$AWS_REGION" \
        --query 'Quota.Value' \
        --output text 2>/dev/null || echo "0")
    
    if [[ "$vcpu_limit" != "0" ]] && [[ "$vcpu_limit" -ge 100 ]]; then
        success "EC2 vCPU limit: $vcpu_limit (minimum 100 required)"
    else
        if [[ "$vcpu_limit" == "0" ]]; then
            warning "Unable to check EC2 vCPU limit (insufficient permissions)"
        else
            error "EC2 vCPU limit: $vcpu_limit (minimum 100 required for ROSA)"
        fi
    fi
    
    # Check EBS volume limits
    local ebs_limit
    ebs_limit=$(aws service-quotas get-service-quota \
        --service-code ec2 \
        --quota-code L-D18FCD1D \
        --region "$AWS_REGION" \
        --query 'Quota.Value' \
        --output text 2>/dev/null || echo "0")
    
    if [[ "$ebs_limit" != "0" ]] && [[ "$ebs_limit" -ge 10 ]]; then
        success "EBS volume limit: $ebs_limit"
    else
        if [[ "$ebs_limit" == "0" ]]; then
            warning "Unable to check EBS volume limit (insufficient permissions)"
        else
            warning "EBS volume limit: $ebs_limit (may be insufficient for large clusters)"
        fi
    fi
    
    # Check VPC limits
    local vpc_limit
    vpc_limit=$(aws service-quotas get-service-quota \
        --service-code vpc \
        --quota-code L-F678F1CE \
        --region "$AWS_REGION" \
        --query 'Quota.Value' \
        --output text 2>/dev/null || echo "0")
    
    if [[ "$vpc_limit" != "0" ]] && [[ "$vpc_limit" -ge 5 ]]; then
        success "VPC limit: $vpc_limit"
    else
        if [[ "$vpc_limit" == "0" ]]; then
            warning "Unable to check VPC limit (insufficient permissions)"
        else
            warning "VPC limit: $vpc_limit (default is 5, may need increase for multiple clusters)"
        fi
    fi
}

# =============================================================================
# ROSA VALIDATION
# =============================================================================

validate_rosa() {
    log "🌹 Validating ROSA configuration..."
    
    # Check ROSA login status
    if rosa whoami &> /dev/null; then
        local user_info
        user_info=$(rosa whoami 2>/dev/null || echo "unknown")
        success "ROSA login status: authenticated as $user_info"
    else
        error "Not logged into ROSA. Run: rosa login"
        return 1
    fi
    
    # Check ROSA permissions
    if rosa verify permissions --region="$AWS_REGION" &> /dev/null; then
        success "ROSA permissions verified"
    else
        error "ROSA permissions verification failed"
        warning "Run: rosa verify permissions --region=$AWS_REGION"
    fi
    
    # Check ROSA quota
    if rosa verify quota --region="$AWS_REGION" &> /dev/null; then
        success "ROSA quota verified"
    else
        error "ROSA quota verification failed"
        warning "Run: rosa verify quota --region=$AWS_REGION"
    fi
    
    # List available ROSA versions
    log "Checking available OpenShift versions..."
    local versions
    versions=$(rosa list versions --channel-group stable 2>/dev/null | grep "4\." | head -5 | awk '{print $1}' | tr '\n' ' ' || echo "unable to fetch")
    if [[ "$versions" != "unable to fetch" ]]; then
        success "Available OpenShift versions: $versions"
    else
        warning "Unable to fetch available OpenShift versions"
    fi
}

# =============================================================================
# TERRAFORM VALIDATION
# =============================================================================

validate_terraform() {
    log "📝 Validating Terraform configuration..."
    
    local terraform_dir="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
    
    # Check if environment directory exists
    if [[ ! -d "$terraform_dir" ]]; then
        error "Terraform environment directory not found: $terraform_dir"
        return 1
    fi
    
    success "Terraform environment directory exists: $terraform_dir"
    
    # Check for required files
    local required_files=("main.tf" "variables.tf" "outputs.tf")
    for file in "${required_files[@]}"; do
        if [[ -f "$terraform_dir/$file" ]]; then
            success "Required file exists: $file"
        else
            error "Required file missing: $file"
        fi
    done
    
    # Check for terraform.tfvars
    if [[ -f "$terraform_dir/terraform.tfvars" ]]; then
        success "Configuration file exists: terraform.tfvars"
    else
        warning "Configuration file not found: terraform.tfvars"
        warning "Copy terraform.tfvars.example to terraform.tfvars and customize"
    fi
    
    # Validate Terraform syntax
    cd "$terraform_dir"
    if terraform fmt -check -recursive . &> /dev/null; then
        success "Terraform code formatting is correct"
    else
        warning "Terraform code formatting issues found (run: terraform fmt -recursive)"
    fi
    
    # Validate Terraform configuration
    if terraform init -backend=false &> /dev/null && terraform validate &> /dev/null; then
        success "Terraform configuration is valid"
    else
        error "Terraform configuration validation failed"
    fi
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# NETWORK VALIDATION
# =============================================================================

validate_network() {
    log "🌐 Validating network connectivity..."
    
    # Check internet connectivity
    if curl -sSf --connect-timeout 10 https://www.google.com > /dev/null 2>&1; then
        success "Internet connectivity verified"
    else
        warning "Internet connectivity issues detected"
    fi
    
    # Check AWS API connectivity
    if curl -sSf --connect-timeout 10 "https://ec2.$AWS_REGION.amazonaws.com" > /dev/null 2>&1; then
        success "AWS API connectivity verified for region $AWS_REGION"
    else
        warning "AWS API connectivity issues for region $AWS_REGION"
    fi
    
    # Check Red Hat connectivity
    if curl -sSf --connect-timeout 10 https://cloud.redhat.com > /dev/null 2>&1; then
        success "Red Hat cloud connectivity verified"
    else
        warning "Red Hat cloud connectivity issues detected"
    fi
    
    # Check OpenShift registry connectivity
    if curl -sSf --connect-timeout 10 https://registry.redhat.io > /dev/null 2>&1; then
        success "OpenShift registry connectivity verified"
    else
        warning "OpenShift registry connectivity issues detected"
    fi
}

# =============================================================================
# SECURITY VALIDATION
# =============================================================================

validate_security() {
    log "🔒 Validating security configuration..."
    
    # Check if running as root (not recommended)
    if [[ $EUID -eq 0 ]]; then
        warning "Running as root user (not recommended for ROSA deployment)"
    else
        success "Running as non-root user"
    fi
    
    # Check SSH agent (for git operations)
    if ssh-add -l &> /dev/null; then
        success "SSH agent is running with loaded keys"
    else
        warning "SSH agent not running or no keys loaded (may affect git operations)"
    fi
    
    # Check for AWS credentials in environment
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] || [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        warning "AWS credentials found in environment variables (consider using IAM roles or AWS profiles)"
    else
        success "No AWS credentials in environment variables"
    fi
    
    # Check for sensitive files in project directory
    local sensitive_patterns=("*.pem" "*.key" "*_rsa" "terraform.tfstate" "*.backup")
    local found_sensitive=false
    
    for pattern in "${sensitive_patterns[@]}"; do
        if find "$PROJECT_ROOT" -name "$pattern" -type f 2>/dev/null | grep -q .; then
            warning "Potentially sensitive files found matching pattern: $pattern"
            found_sensitive=true
        fi
    done
    
    if [[ "$found_sensitive" == false ]]; then
        success "No obviously sensitive files found in project directory"
    fi
}

# =============================================================================
# GENERATE VALIDATION REPORT
# =============================================================================

generate_report() {
    log "📋 Generating validation report..."
    
    local report_file="$PROJECT_ROOT/validation-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "ROSA Deployment Validation Report"
        echo "Generated: $(date)"
        echo "Environment: $ENVIRONMENT"
        echo "AWS Region: $AWS_REGION"
        echo "====================================="
        echo
        
        for result in "${VALIDATION_RESULTS[@]}"; do
            echo "$result"
        done
        
        echo
        echo "====================================="
        if [[ "$VALIDATION_PASSED" == true ]]; then
            echo "Overall Status: ✅ PASSED"
            echo "The environment is ready for ROSA deployment."
        else
            echo "Overall Status: ❌ FAILED"
            echo "Please address the issues above before deploying."
        fi
        echo "====================================="
        
    } | tee "$report_file"
    
    success "Validation report saved to: $report_file"
}

# =============================================================================
# MAIN VALIDATION WORKFLOW
# =============================================================================

main() {
    log "🔍 Starting ROSA environment validation..."
    log "Environment: $ENVIRONMENT"
    log "AWS Region: $AWS_REGION"
    echo
    
    # Run all validations
    validate_system
    echo
    
    validate_tools
    echo
    
    validate_aws
    echo
    
    validate_aws_quotas
    echo
    
    validate_rosa
    echo
    
    validate_terraform
    echo
    
    validate_network
    echo
    
    validate_security
    echo
    
    # Generate report
    generate_report
    
    # Final status
    if [[ "$VALIDATION_PASSED" == true ]]; then
        success "🎉 All validations passed! Environment is ready for ROSA deployment."
        echo
        echo "Next steps:"
        echo "1. Review and customize terraform.tfvars in terraform/environments/$ENVIRONMENT/"
        echo "2. Run the deployment script: ./scripts/deploy-rosa.sh $ENVIRONMENT"
        echo
        exit 0
    else
        error "❌ Some validations failed. Please address the issues before proceeding."
        echo
        echo "Common solutions:"
        echo "- Install missing tools"
        echo "- Configure AWS credentials: aws configure"
        echo "- Login to ROSA: rosa login"
        echo "- Request quota increases if needed"
        echo
        exit 1
    fi
}

# Show usage if help requested
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [ENVIRONMENT] [AWS_REGION]"
    echo
    echo "Arguments:"
    echo "  ENVIRONMENT  Environment to validate (default: prod)"
    echo "  AWS_REGION   AWS region to validate (default: us-east-1)"
    echo
    echo "Examples:"
    echo "  $0                    # Validate prod environment in us-east-1"
    echo "  $0 staging            # Validate staging environment"
    echo "  $0 prod us-west-2     # Validate prod in us-west-2"
    echo
    exit 0
fi

# Run main function
main "$@"