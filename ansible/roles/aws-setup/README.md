# AWS Setup Role

## Overview
The `aws-setup` role provides comprehensive AWS CLI setup, configuration validation, and ROSA service enablement for ROSA cluster deployments.

## Features
- ✅ AWS CLI installation and verification
- ✅ AWS Profile-based authentication (Enhanced Security)
- ✅ Service account validation with admin permission checks
- ✅ Environment setup and .env file management
- ✅ **ROSA service enablement and validation** 🚀
- ✅ Cross-platform support (Linux, macOS)
- ✅ Comprehensive error handling

## Prerequisites
- AWS CLI configured with named profiles
- AWS profile must have `AdministratorAccess` policy
- Profile credentials must be valid and not expired

## Required Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `aws_profile` | AWS profile name | **Yes** | None |
| `target_environment` | Environment (dev/test/prod) | **Yes** | None |
| `aws_region` | AWS region | No | us-east-1 |

## Usage

### Basic Usage
```bash
ansible-playbook playbooks/main.yml \
  --extra-vars "aws_profile=svktek target_environment=dev" \
  --tags "aws"
```

### With Custom Region
```bash
ansible-playbook playbooks/main.yml \
  --extra-vars "aws_profile=production target_environment=prod aws_region=us-west-2" \
  --tags "aws"
```

### With Verbose Output
```bash
ansible-playbook playbooks/main.yml \
  --extra-vars "aws_profile=svktek target_environment=dev" \
  --tags "aws" -v
```

## ROSA Service Validation

The role includes comprehensive ROSA service validation:

### Service Detection
- Automatically checks if ROSA service is enabled using `rosa verify quota`
- Uses proper AWS profile environment variables
- Handles region-specific validation

### Auto-enablement
- Attempts to enable the service programmatically using `rosa create account-roles`
- Provides fallback to manual enablement instructions

### Manual Enablement Instructions
If automatic enablement fails, the role provides clear manual steps:
1. Visit: https://console.aws.amazon.com/rosa/home
2. Click 'Enable OpenShift' button
3. Review and accept the terms of service
4. Complete the service enablement process
5. Re-run this playbook after enablement

### Validation Modes
- **Strict validation** (default): Fails if ROSA service is not enabled
- **Lenient validation**: Warns but continues if `strict_validation: false`

## Task Breakdown

### Task 1: AWS CLI Installation
- Multi-platform support (Ubuntu/Debian, RedHat/CentOS, macOS)
- Version verification and validation
- Automatic installer download and setup

### Task 2: Service Account Validation (Profile-based)
- AWS profile validation and identity verification
- Admin permission checks (AdministratorAccess policy)
- User group membership validation
- Security warnings for root account usage

### Task 3: Environment Setup
- Environment-specific directory creation
- .env file generation and updates
- Environment variable exports
- Terraform workspace configuration

### Task 4: ROSA Service Enablement ⭐ NEW
- Service status verification using `rosa verify quota`
- Automatic service enablement attempt
- Manual enablement instructions
- Comprehensive status reporting

## AWS Profile Configuration

### Setup AWS Profile
```bash
# Interactive configuration
aws configure --profile svktek

# Manual configuration in ~/.aws/credentials
[svktek]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
region = us-east-1
output = json
```

### Verify Profile
```bash
# Test profile
aws sts get-caller-identity --profile svktek

# List available profiles
aws configure list-profiles
```

### Advanced: IAM Role Profiles
```bash
# ~/.aws/config
[profile svktek-role]
role_arn = arn:aws:iam::123456789012:role/AdminRole
source_profile = svktek
region = us-east-1
```

## Security Features

### Enhanced Security Model
- ✅ **No plaintext credentials** in playbooks
- ✅ **Profile-based authentication** using AWS CLI profiles
- ✅ **Environment variable isolation** per task
- ✅ **Credential validation** without logging sensitive data
- ✅ **Admin permission verification** before proceeding

### Best Practices Implemented
- `no_log: true` for credential-related tasks
- Environment variable scoping per shell command
- Secure credential validation using `aws sts get-caller-identity`
- Administrative access verification before cluster operations

## Error Handling

### Common Issues and Solutions

#### AWS CLI Installation Fails
- Check internet connectivity
- Verify system architecture (x86_64)
- Ensure sufficient disk space
- Check for conflicting installations

#### Service Account Validation Fails
- Verify AWS credentials are correct
- Check IAM policy attachments
- Ensure account has required permissions
- Verify account is not suspended

#### ROSA Service Validation Fails
- Ensure ROSA CLI is installed (`rosa version`)
- Check AWS profile has proper permissions
- Verify account is enabled for ROSA service
- Follow manual enablement instructions if needed

#### Environment Setup Issues
- Check directory permissions
- Verify .env file is readable
- Ensure environment variable exports work

## Integration

### Main Playbook Integration
```yaml
roles:
  - role: aws-setup
    tags: ['aws', 'setup']
  - role: rosa-cli
    tags: ['rosa', 'cli']
  - role: cluster
    tags: ['cluster']
```

### Tag-based Execution
```bash
# Run only AWS setup
ansible-playbook playbooks/main.yml --tags "aws"

# Run AWS setup and ROSA CLI
ansible-playbook playbooks/main.yml --tags "aws,rosa"

# Run specific ROSA service validation
ansible-playbook playbooks/main.yml --tags "rosa-service"
```

## Outputs

### Generated Files
- `environments/{environment}/.env` - Environment configuration
- `environments/{environment}/export_env.sh` - Environment export script

### Environment Variables Set
- `AWS_PROFILE` - AWS profile name
- `AWS_REGION` - AWS region
- `ENVIRONMENT` - Target environment
- `TERRAFORM_WORKSPACE` - Terraform workspace

## Troubleshooting

### Debug Mode
```bash
# Maximum verbosity
ansible-playbook playbooks/main.yml --tags "aws" -vvv

# Check syntax
ansible-playbook playbooks/main.yml --syntax-check

# Dry run
ansible-playbook playbooks/main.yml --check
```

### Manual ROSA Service Check
```bash
# Check ROSA service status
export AWS_PROFILE=svktek
rosa verify quota

# Check ROSA authentication
rosa whoami

# Manual account role creation
rosa create account-roles --mode auto --yes
```

## Version Information
- Role Version: 2.0.0
- AWS CLI Support: v2
- ROSA CLI Support: Latest
- Ansible Version: >=2.9

## License
MIT

## Author
DevOps Team - Consulting Firm