# ROSA Infrastructure Ansible Automation

## Overview
This repository contains Ansible automation for setting up ROSA (Red Hat OpenShift Service on AWS) infrastructure. The automation includes AWS CLI setup, ROSA CLI configuration, authentication, and environment variable management.

## Repository Structure
```
ansible/
├── playbooks/
│   └── main.yml                    # Master playbook
├── roles/
│   ├── aws-setup/                  # AWS CLI and environment setup
│   │   ├── defaults/main.yml       # Default variables
│   │   ├── meta/main.yml          # Role metadata
│   │   ├── tasks/
│   │   │   ├── main.yml           # Main task orchestration
│   │   │   ├── install_aws_cli.yml # AWS CLI installation
│   │   │   ├── setup_environment.yml # Environment configuration
│   │   │   └── validate_service_account.yml # AWS validation
│   │   ├── templates/             # Jinja2 templates
│   │   └── vars/main.yml          # Role variables
│   ├── rosa-cli/                   # ROSA CLI setup and configuration
│   │   ├── defaults/main.yml       # Default variables
│   │   ├── meta/main.yml          # Role metadata
│   │   ├── tasks/
│   │   │   ├── main.yml           # Main task orchestration
│   │   │   ├── check_install_rosa_cli.yml # ROSA CLI installation
│   │   │   ├── rosa_authentication.yml # Authentication setup
│   │   │   └── configure_environment.yml # Environment configuration
│   │   └── vars/main.yml          # Role variables
│   └── validation/                 # Infrastructure validation
└── README.md                      # This file
```

## Prerequisites

### System Requirements
- Ansible 2.9+ installed
- Linux/macOS environment
- Internet connectivity for downloading CLI tools
- sudo privileges for CLI installation

### Account Requirements
- AWS account with appropriate permissions
- Red Hat account with ROSA access
- Valid ROSA authentication token

### Environment Setup
1. Clone this repository
2. Ensure Ansible is installed: `ansible --version`
3. Set up your AWS credentials (AWS CLI or environment variables)
4. Obtain your ROSA authentication token from https://console.redhat.com/openshift/token/rosa

## Execution Instructions

### 1. Execute All Roles (Complete Setup)

#### Basic Execution
```bash
# Run complete ROSA infrastructure setup
ansible-playbook playbooks/main.yml

# Run with specific environment
ansible-playbook playbooks/main.yml -e "environment=dev"
ansible-playbook playbooks/main.yml -e "environment=test"
ansible-playbook playbooks/main.yml -e "environment=prod"

# Run with custom AWS region
ansible-playbook playbooks/main.yml -e "environment=dev" -e "region=us-west-2"
```

#### With Custom Variables
```bash
# Run with all custom variables
ansible-playbook playbooks/main.yml \
  -e "environment=prod" \
  -e "region=us-west-2" \
  -e "aws_profile=production" \
  -e "rosa_cli_version=1.2.25"
```

#### Mandatory Variables for Complete Setup
| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `environment` | dev | Target environment (dev/test/prod) | Yes |
| `region` | us-east-1 | AWS region | No |
| `aws_profile` | svktek | AWS profile name | No |

### 2. Execute AWS Setup Role Only

#### Basic AWS Setup
```bash
# Run only AWS setup tasks
ansible-playbook playbooks/main.yml --tags aws-setup

# Run AWS setup for specific environment
ansible-playbook playbooks/main.yml --tags aws-setup -e "environment=prod"
```

#### AWS Setup with Custom Variables
```bash
# AWS setup with custom configuration
ansible-playbook playbooks/main.yml --tags aws-setup \
  -e "target_environment=prod" \
  -e "aws_region=us-west-2" \
  -e "aws_cli_version=2"
```

#### Mandatory Variables for AWS Setup
| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `target_environment` | "" | Target environment | Yes |
| `aws_region` | us-east-1 | AWS region | No |
| `terraform_base_path` | /Users/swaroop/Documents/FullStack-SRE/ConsultingFirm_infra/ROSA/terraform/environments | Terraform path | No |

### 3. Execute ROSA CLI Role Only

#### Basic ROSA CLI Setup
```bash
# Run only ROSA CLI tasks
ansible-playbook playbooks/main.yml --tags rosa-cli

# Run ROSA CLI setup for specific environment
ansible-playbook playbooks/main.yml --tags rosa-cli -e "environment=test"
```

#### ROSA CLI with Custom Variables
```bash
# ROSA CLI setup with custom configuration
ansible-playbook playbooks/main.yml --tags rosa-cli \
  -e "environment=prod" \
  -e "rosa_cli_install_path=/opt/rosa" \
  -e "terraform_env_path=/custom/path/terraform/environments"
```

#### Mandatory Variables for ROSA CLI
| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `environment` | "" | Target environment | Yes |
| `terraform_env_path` | (calculated) | Path to terraform environments | No |
| `rosa_auth_token` | "" | ROSA authentication token | Yes* |

*Note: If not provided via variable, will be prompted during execution

### 4. Execute Individual Tasks

#### AWS Setup Individual Tasks
```bash
# Install AWS CLI only
ansible-playbook playbooks/main.yml --tags aws-setup -e "target_environment=dev" \
  --extra-vars "{'aws_setup_tasks': ['install_aws_cli']}"

# Validate service account only
ansible-playbook playbooks/main.yml --tags aws-setup -e "target_environment=dev" \
  --extra-vars "{'aws_setup_tasks': ['validate_service_account']}"

# Setup environment only
ansible-playbook playbooks/main.yml --tags aws-setup -e "target_environment=dev" \
  --extra-vars "{'aws_setup_tasks': ['setup_environment']}"
```

#### ROSA CLI Individual Tasks
```bash
# Install/Update ROSA CLI only
ansible-playbook playbooks/main.yml --tags rosa-cli-install -e "environment=dev"

# ROSA authentication only
ansible-playbook playbooks/main.yml --tags rosa-auth -e "environment=dev" \
  -e "rosa_auth_token=YOUR_TOKEN_HERE"

# Environment configuration only
ansible-playbook playbooks/main.yml --tags rosa-env -e "environment=dev" \
  -e "validated_rosa_token=YOUR_TOKEN_HERE"
```

### 5. Advanced Execution Options

#### Skip Specific Roles
```bash
# Skip validation role
ansible-playbook playbooks/main.yml --skip-tags validation

# Skip AWS setup if already configured
ansible-playbook playbooks/main.yml --skip-tags aws-setup
```

#### Dry Run (Check Mode)
```bash
# Test without making changes
ansible-playbook playbooks/main.yml --check --diff

# Test specific role
ansible-playbook playbooks/main.yml --check --tags rosa-cli
```

#### Verbose Output
```bash
# Run with verbose output
ansible-playbook playbooks/main.yml -v    # Basic verbose
ansible-playbook playbooks/main.yml -vv   # More verbose
ansible-playbook playbooks/main.yml -vvv  # Debug level
```

#### Run with Specific Inventory
```bash
# Use custom inventory
ansible-playbook -i inventory/production playbooks/main.yml -e "environment=prod"
```

## Variable Reference

### Global Variables
These variables are available to all roles:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `environment` | string | dev | Target environment (dev/test/prod) |
| `region` | string | us-east-1 | AWS region |
| `aws_profile` | string | svktek | AWS profile name |
| `terraform_base_path` | string | /Users/swaroop/Documents/FullStack-SRE/ConsultingFirm_infra/ROSA/terraform/environments | Base path for terraform |

### AWS Setup Role Variables
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `target_environment` | string | "" | Target environment (required) |
| `aws_region` | string | us-east-1 | AWS region |
| `aws_output_format` | string | json | AWS CLI output format |
| `aws_cli_version` | string | 2 | AWS CLI version |
| `terraform_base_path` | string | /Users/swaroop/Documents/FullStack-SRE/ConsultingFirm_infra/ROSA/terraform/environments | Terraform path |

### ROSA CLI Role Variables
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `environment` | string | "" | Target environment (required) |
| `rosa_cli_version` | string | latest | ROSA CLI version |
| `rosa_cli_install_path` | string | /usr/local/bin | Installation path |
| `rosa_auth_token` | string | "" | ROSA authentication token |
| `terraform_env_path` | string | (calculated) | Path to terraform environments |

## Environment-Specific Configuration

### Development Environment
```bash
ansible-playbook playbooks/main.yml -e "environment=dev"
```
- Uses development AWS resources
- Less strict validation
- Faster setup for testing

### Test Environment
```bash
ansible-playbook playbooks/main.yml -e "environment=test"
```
- Mirrors production setup
- Full validation enabled
- Used for integration testing

### Production Environment
```bash
ansible-playbook playbooks/main.yml -e "environment=prod"
```
- Production-grade configuration
- Strict validation and security
- Backup and monitoring enabled

## Troubleshooting

### Common Issues

#### 1. AWS CLI Installation Fails
```bash
# Check prerequisites
which curl unzip
sudo yum install -y curl unzip  # RHEL/CentOS
sudo apt-get install -y curl unzip  # Ubuntu/Debian

# Run with verbose output
ansible-playbook playbooks/main.yml --tags aws-setup -vvv
```

#### 2. ROSA Authentication Fails
```bash
# Verify token validity
rosa login --token=YOUR_TOKEN

# Check token format (should start with 'sha256~')
echo $ROSA_TOKEN | head -c 20

# Get fresh token from https://console.redhat.com/openshift/token/rosa
```

#### 3. Permission Denied Errors
```bash
# Run with sudo for CLI installation
ansible-playbook playbooks/main.yml --become --ask-become-pass

# Check file permissions
ls -la /usr/local/bin/rosa
```

#### 4. Environment Variable Issues
```bash
# Check generated environment file
cat terraform/environments/dev/export_env.sh

# Source the file manually
source terraform/environments/dev/export_env.sh
echo $ROSA_TOKEN
```

### Debugging Commands
```bash
# Check Ansible configuration
ansible-config dump

# Validate playbook syntax
ansible-playbook playbooks/main.yml --syntax-check

# Test connectivity
ansible localhost -m ping

# Check role dependencies
ansible-galaxy list
```

### Log Files
- Playbook execution logs: `logs/execution.log`
- Error logs: `logs/error_*.log`
- Setup summary: `logs/rosa_setup_*.log`

## Security Considerations

### Token Management
- Never commit ROSA tokens to version control
- Use environment variables or prompt for tokens
- Tokens expire after 24 hours
- Store tokens securely using tools like HashiCorp Vault

### File Permissions
- Environment files created with 0755 permissions
- Temporary files cleaned up after use
- Sensitive operations use `no_log: true`

### Network Security
- ROSA CLI downloads use HTTPS
- Validation checks verify SSL certificates
- All external API calls use encrypted connections

## Performance Optimization

### Parallel Execution
```bash
# Run independent roles in parallel
ansible-playbook playbooks/main.yml --forks=10
```

### Caching
```bash
# Enable fact caching
export ANSIBLE_CACHE_PLUGIN=memory
export ANSIBLE_CACHE_PLUGIN_TIMEOUT=3600
```

### Reduced Gathering
```bash
# Skip fact gathering if not needed
ansible-playbook playbooks/main.yml --extra-vars "gather_facts=no"
```

## Integration Examples

### CI/CD Pipeline Integration
```yaml
# .github/workflows/rosa-setup.yml
- name: Setup ROSA Infrastructure
  run: |
    ansible-playbook ansible/playbooks/main.yml \
      -e "environment=${{ matrix.environment }}" \
      -e "rosa_auth_token=${{ secrets.ROSA_TOKEN }}"
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### Terraform Integration
```bash
# Setup environment then run Terraform
ansible-playbook playbooks/main.yml -e "environment=dev"
source terraform/environments/dev/export_env.sh
cd terraform/environments/dev
terraform plan
```

### Script Integration
```bash
#!/bin/bash
# deploy.sh - Complete deployment script
set -e

ENVIRONMENT=${1:-dev}

echo "Setting up ROSA infrastructure for $ENVIRONMENT..."
ansible-playbook ansible/playbooks/main.yml -e "environment=$ENVIRONMENT"

echo "Sourcing environment variables..."
source terraform/environments/$ENVIRONMENT/export_env.sh

echo "Deploying infrastructure..."
cd terraform/environments/$ENVIRONMENT
terraform init
terraform plan
terraform apply -auto-approve

echo "Deployment complete!"
```

## Support and Contributing

### Getting Help
- Check the troubleshooting section above
- Review logs in the `logs/` directory
- Run with verbose output (`-vvv`) for detailed debugging
- Consult the learning modules in `docs/ansible/`

### Contributing
1. Follow the existing role structure
2. Add comprehensive documentation
3. Include variable validation
4. Test in all environments (dev/test/prod)
5. Update this README with any new features

### Learning Resources
- [Master Playbook Learning Module](/Users/swaroop/Documents/FullStack-SRE/ConsultingFirm_infra/ROSA/docs/ansible/MASTER-PLAYBOOK-LEARNING-MODULE.md)
- [ROSA CLI Role Learning Module](/Users/swaroop/Documents/FullStack-SRE/ConsultingFirm_infra/ROSA/docs/ansible/ROSA-CLI-ROLE-LEARNING-MODULE.md)
- [AWS Setup Role Learning Module](/Users/swaroop/Documents/FullStack-SRE/ConsultingFirm_infra/ROSA/docs/ansible/AWS-SETUP-ROLE-LEARNING-MODULE.md)

---

## Quick Reference

### Most Common Commands
```bash
# Complete setup
ansible-playbook playbooks/main.yml -e "environment=dev"

# AWS only
ansible-playbook playbooks/main.yml --tags aws-setup -e "target_environment=dev"

# ROSA only
ansible-playbook playbooks/main.yml --tags rosa-cli -e "environment=dev"

# Dry run
ansible-playbook playbooks/main.yml --check -e "environment=dev"

# With token
ansible-playbook playbooks/main.yml -e "environment=dev" -e "rosa_auth_token=TOKEN"
```

This automation provides a complete, production-ready solution for ROSA infrastructure setup with comprehensive error handling, security considerations, and flexibility for different environments.