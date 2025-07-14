# AWS Setup Role Learning Module

## Overview
This learning module will guide you through creating the `aws-setup` Ansible role step-by-step. By the end of this module, you'll understand how to build a complete Ansible role that:

1. Checks and installs AWS CLI
2. Validates AWS service account configuration
3. Sets up environment variables and updates .env files
4. **Validates and enables ROSA service in AWS account** 🚀

## Prerequisites
- Basic understanding of Ansible concepts (roles, tasks, handlers)
- Understanding of YAML syntax
- Basic knowledge of AWS CLI and service accounts

## Existing Project Structure

Before we start, let's examine the existing ansible folder structure:

```
ansible/
├── host_vars/
├── outputs/
└── roles/
    ├── aws-setup/           # Our target role
    │   ├── defaults/
    │   ├── files/
    │   ├── handlers/
    │   ├── meta/
    │   ├── templates/
    │   └── vars/
    ├── rosa-cli/
    │   ├── files/
    │   ├── handlers/
    │   ├── templates/
    │   └── vars/
    └── validation/
        ├── defaults/
        ├── files/
        ├── handlers/
        ├── meta/
        ├── tasks/
        ├── templates/
        └── vars/
```

## Step 1: Understanding the aws-setup Role Structure

The `aws-setup` role directory structure follows Ansible best practices:

- **tasks/**: Contains the main logic and task definitions
- **defaults/**: Default variables for the role
- **vars/**: Role-specific variables
- **handlers/**: Event handlers triggered by tasks
- **templates/**: Jinja2 templates for configuration files
- **files/**: Static files to be copied to target hosts
- **meta/**: Role metadata and dependencies

## Step 2: Creating the Main Tasks File

First, we need to create the main tasks file that will orchestrate our three main tasks.

**File to create**: `ansible/roles/aws-setup/tasks/main.yml`

```yaml
---
# Main tasks file for aws-setup role
# This file coordinates the execution of all aws-setup related tasks

- name: "AWS Setup - Starting configuration"
  debug:
    msg: "Starting AWS CLI setup and configuration validation"

- name: "Include AWS CLI installation tasks"
  include_tasks: install_aws_cli.yml

- name: "Include AWS service account validation tasks"
  include_tasks: validate_service_account.yml

- name: "Include environment setup tasks"
  include_tasks: setup_environment.yml

- name: "Include ROSA service enablement tasks"
  include_tasks: enable_rosa_service.yml

- name: "AWS Setup - Configuration complete"
  debug:
    msg: "AWS CLI setup and configuration validation completed successfully"
```

## Step 3: Task 1 - AWS CLI Check and Installation

**File to create**: `ansible/roles/aws-setup/tasks/install_aws_cli.yml`

```yaml
---
# Task 1: Check if AWS CLI is installed and install if needed

- name: "Check if AWS CLI is installed"
  command: aws --version
  register: aws_cli_check
  ignore_errors: yes
  changed_when: false

- name: "Display AWS CLI status"
  debug:
    msg: "AWS CLI is {{ 'installed' if aws_cli_check.rc == 0 else 'not installed' }}"

- name: "Install AWS CLI (Ubuntu/Debian)"
  block:
    - name: "Download AWS CLI installer"
      get_url:
        url: "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
        dest: "/tmp/awscliv2.zip"
        mode: '0644'

    - name: "Unzip AWS CLI installer"
      unarchive:
        src: "/tmp/awscliv2.zip"
        dest: "/tmp"
        remote_src: yes

    - name: "Install AWS CLI"
      command: /tmp/aws/install
      become: yes

    - name: "Verify AWS CLI installation"
      command: aws --version
      register: aws_cli_verify
      changed_when: false

    - name: "Display AWS CLI version"
      debug:
        msg: "AWS CLI installed successfully: {{ aws_cli_verify.stdout }}"

  when: aws_cli_check.rc != 0 and ansible_os_family == "Debian"

- name: "Install AWS CLI (RedHat/CentOS)"
  block:
    - name: "Download AWS CLI installer"
      get_url:
        url: "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
        dest: "/tmp/awscliv2.zip"
        mode: '0644'

    - name: "Install unzip if not present"
      package:
        name: unzip
        state: present
      become: yes

    - name: "Unzip AWS CLI installer"
      unarchive:
        src: "/tmp/awscliv2.zip"
        dest: "/tmp"
        remote_src: yes

    - name: "Install AWS CLI"
      command: /tmp/aws/install
      become: yes

    - name: "Verify AWS CLI installation"
      command: aws --version
      register: aws_cli_verify
      changed_when: false

    - name: "Display AWS CLI version"
      debug:
        msg: "AWS CLI installed successfully: {{ aws_cli_verify.stdout }}"

  when: aws_cli_check.rc != 0 and ansible_os_family == "RedHat"

- name: "Install AWS CLI (macOS)"
  block:
    - name: "Download AWS CLI installer for macOS"
      get_url:
        url: "https://awscli.amazonaws.com/AWSCLIV2.pkg"
        dest: "/tmp/AWSCLIV2.pkg"
        mode: '0644'

    - name: "Install AWS CLI on macOS"
      command: installer -pkg /tmp/AWSCLIV2.pkg -target /
      become: yes

    - name: "Verify AWS CLI installation"
      command: aws --version
      register: aws_cli_verify
      changed_when: false

    - name: "Display AWS CLI version"
      debug:
        msg: "AWS CLI installed successfully: {{ aws_cli_verify.stdout }}"

  when: aws_cli_check.rc != 0 and ansible_os_family == "Darwin"

- name: "Fail if AWS CLI installation not supported"
  fail:
    msg: "AWS CLI installation not supported for {{ ansible_os_family }}"
  when: aws_cli_check.rc != 0 and ansible_os_family not in ["Debian", "RedHat", "Darwin"]
```

## Step 4: Task 2 - AWS Profile Validation (UPDATED)

**File to create**: `ansible/roles/aws-setup/tasks/validate_service_account.yml`

> **⚠️ UPDATED**: This task now supports AWS profiles as primary authentication method for enhanced security.

```yaml
---
# Task 2: Validate AWS service account configuration

- name: "Prompt for AWS profile name"
  pause:
    prompt: "Please enter your AWS profile name"
  register: aws_profile_input
  when: aws_profile is not defined

- name: "Set AWS profile from input"
  set_fact:
    aws_profile: "{{ aws_profile_input.user_input if aws_profile_input.user_input is defined else aws_profile }}"

- name: "Validate AWS profile is provided"
  fail:
    msg: "AWS profile name is required. Please provide aws_profile variable or enter it when prompted."
  when: aws_profile is not defined or aws_profile == ""

- name: "Export AWS profile environment variable"
  shell: export AWS_PROFILE={{ aws_profile }}
  environment:
    AWS_PROFILE: "{{ aws_profile }}"

- name: "Set AWS region for profile"
  shell: |
    export AWS_PROFILE={{ aws_profile }}
    aws configure set region {{ aws_region | default('us-east-1') }} --profile {{ aws_profile }}
  environment:
    AWS_PROFILE: "{{ aws_profile }}"

- name: "Test AWS configuration"
  command: aws sts get-caller-identity
  register: aws_identity_check
  ignore_errors: yes
  environment:
    AWS_PROFILE: "{{ aws_profile }}"

- name: "Parse AWS identity information"
  set_fact:
    aws_identity: "{{ aws_identity_check.stdout | from_json }}"
  when: aws_identity_check.rc == 0

- name: "Display AWS identity information"
  debug:
    msg: |
      AWS Identity Information:
      - Account ID: {{ aws_identity.Account }}
      - User ARN: {{ aws_identity.Arn }}
      - User ID: {{ aws_identity.UserId }}
  when: aws_identity_check.rc == 0

- name: "Fail if AWS credentials are not configured"
  fail:
    msg: |
      AWS credentials are not properly configured or invalid.
      Error: {{ aws_identity_check.stderr }}
      Please ensure you have provided valid AWS credentials with appropriate permissions.
  when: aws_identity_check.rc != 0

- name: "Check if user has admin permissions"
  command: aws iam get-user
  register: aws_user_check
  ignore_errors: yes

- name: "Check attached user policies"
  command: aws iam list-attached-user-policies --user-name {{ aws_identity.Arn.split('/')[-1] }}
  register: aws_user_policies
  ignore_errors: yes
  when: aws_identity_check.rc == 0
  environment:
    AWS_PROFILE: "{{ aws_profile }}"

- name: "Check user groups"
  command: aws iam list-groups-for-user --user-name {{ aws_identity.Arn.split('/')[-1] }}
  register: aws_user_groups
  ignore_errors: yes
  when: aws_identity_check.rc == 0
  environment:
    AWS_PROFILE: "{{ aws_profile }}"

- name: "Validate admin permissions"
  block:
    - name: "Parse user policies"
      set_fact:
        user_policies: "{{ aws_user_policies.stdout | from_json }}"
      when: aws_user_policies.rc == 0

    - name: "Parse user groups"
      set_fact:
        user_groups: "{{ aws_user_groups.stdout | from_json }}"
      when: aws_user_groups.rc == 0

    - name: "Check for admin policy"
      set_fact:
        has_admin_policy: "{{ user_policies.AttachedPolicies | selectattr('PolicyName', 'equalto', 'AdministratorAccess') | list | length > 0 }}"
      when: user_policies is defined

    - name: "Check for admin group membership"
      set_fact:
        has_admin_group: "{{ user_groups.Groups | selectattr('GroupName', 'search', '[Aa]dmin') | list | length > 0 }}"
      when: user_groups is defined

    - name: "Verify admin access"
      fail:
        msg: |
          The provided service account does not have administrator access.
          Please provide a service account with AdministratorAccess policy or admin group membership.
          
          Current policies: {{ user_policies.AttachedPolicies | map(attribute='PolicyName') | list if user_policies is defined else 'Unable to retrieve' }}
          Current groups: {{ user_groups.Groups | map(attribute='GroupName') | list if user_groups is defined else 'Unable to retrieve' }}
      when: 
        - not (has_admin_policy | default(false))
        - not (has_admin_group | default(false))

  when: aws_identity_check.rc == 0

- name: "Warn about root account usage"
  debug:
    msg: |
      WARNING: It appears you may be using root account credentials.
      For security best practices, please use an IAM user with AdministratorAccess policy instead.
  when: aws_identity.Arn is defined and 'root' in aws_identity.Arn
```

## Step 5: Task 3 - Environment Setup

**File to create**: `ansible/roles/aws-setup/tasks/setup_environment.yml`

```yaml
---
# Task 3: Environment setup and .env file updates

- name: "Prompt for environment selection"
  pause:
    prompt: "Please select the environment (dev/test/prod)"
  register: environment_input
  when: target_environment is not defined

- name: "Set target environment"
  set_fact:
    target_environment: "{{ environment_input.user_input if environment_input.user_input is defined else target_environment }}"

- name: "Validate environment selection"
  fail:
    msg: "Invalid environment selection. Please choose from: dev, test, prod"
  when: target_environment not in ['dev', 'test', 'prod']

- name: "Set terraform environment path"
  set_fact:
    terraform_env_path: "{{ playbook_dir }}/../terraform/environments/{{ target_environment }}"

- name: "Check if terraform environment directory exists"
  stat:
    path: "{{ terraform_env_path }}"
  register: terraform_env_dir

- name: "Create terraform environment directory if it doesn't exist"
  file:
    path: "{{ terraform_env_path }}"
    state: directory
    mode: '0755'
  when: not terraform_env_dir.stat.exists

- name: "Check if .env file exists"
  stat:
    path: "{{ terraform_env_path }}/.env"
  register: env_file_check

- name: "Create .env file from template"
  template:
    src: env.j2
    dest: "{{ terraform_env_path }}/.env"
    mode: '0644'
  when: not env_file_check.stat.exists

- name: "Update .env file with AWS credentials"
  blockinfile:
    path: "{{ terraform_env_path }}/.env"
    block: |
      # AWS Configuration
      AWS_ACCESS_KEY_ID={{ aws_access_key_id }}
      AWS_SECRET_ACCESS_KEY={{ aws_secret_access_key }}
      AWS_DEFAULT_REGION={{ aws_region | default('us-east-1') }}
      AWS_REGION={{ aws_region | default('us-east-1') }}
      
      # Environment Configuration
      ENVIRONMENT={{ target_environment }}
      TERRAFORM_WORKSPACE={{ target_environment }}
    marker: "# {mark} ANSIBLE MANAGED AWS BLOCK"
    create: yes
  no_log: true

- name: "Set environment variables in current session"
  shell: |
    export AWS_ACCESS_KEY_ID={{ aws_access_key_id }}
    export AWS_SECRET_ACCESS_KEY={{ aws_secret_access_key }}
    export AWS_DEFAULT_REGION={{ aws_region | default('us-east-1') }}
    export AWS_REGION={{ aws_region | default('us-east-1') }}
    export ENVIRONMENT={{ target_environment }}
    export TERRAFORM_WORKSPACE={{ target_environment }}
  no_log: true

- name: "Create environment export script"
  template:
    src: export_env.sh.j2
    dest: "{{ terraform_env_path }}/export_env.sh"
    mode: '0755'

- name: "Display environment setup completion"
  debug:
    msg: |
      Environment setup completed successfully!
      
      Configuration:
      - Environment: {{ target_environment }}
      - Terraform path: {{ terraform_env_path }}
      - .env file updated: {{ terraform_env_path }}/.env
      - Export script created: {{ terraform_env_path }}/export_env.sh
      
      To use the environment variables in your shell, run:
      source {{ terraform_env_path }}/export_env.sh
```

## Step 6: Task 4 - ROSA Service Enablement

**File to create**: `ansible/roles/aws-setup/tasks/enable_rosa_service.yml`

> **🚀 NEW**: This task validates and enables ROSA service in the AWS account to prevent cluster creation failures.

```yaml
---
# Task 4: Enable ROSA service in AWS account

- name: "Check if ROSA service is enabled in AWS account"
  shell: |
    rosa verify quota --region {{ aws_region | default('us-east-1') }}
  register: rosa_service_check
  changed_when: false
  failed_when: false
  environment:
    AWS_PROFILE: "{{ aws_profile }}"
  tags:
    - aws
    - rosa-service

- name: "Display current ROSA service status"
  debug:
    msg:
      - "🔍 ROSA Service Status Check:"
      - "  - Command exit code: {{ rosa_service_check.rc }}"
      - "  - Service enabled: {{ rosa_service_check.rc == 0 }}"
  tags:
    - aws
    - rosa-service

- name: "Attempt to enable ROSA service automatically"
  shell: |
    rosa create account-roles --mode auto --yes
  register: rosa_service_enable
  when: rosa_service_check.rc != 0
  failed_when: false
  environment:
    AWS_PROFILE: "{{ aws_profile }}"
  tags:
    - aws
    - rosa-service

- name: "Check ROSA service status after enabling attempt"
  shell: |
    rosa verify quota --region {{ aws_region | default('us-east-1') }}
  register: rosa_service_recheck
  changed_when: false
  failed_when: false
  when: rosa_service_check.rc != 0
  environment:
    AWS_PROFILE: "{{ aws_profile }}"
  tags:
    - aws
    - rosa-service

- name: "Set ROSA service status facts"
  set_fact:
    rosa_service_enabled: "{{ (rosa_service_check.rc == 0) or (rosa_service_recheck.rc == 0 if rosa_service_recheck is defined else false) }}"
    rosa_service_auto_enabled: "{{ rosa_service_check.rc != 0 and (rosa_service_recheck.rc == 0 if rosa_service_recheck is defined else false) }}"
  tags:
    - aws
    - rosa-service

- name: "Display ROSA service enablement result"
  debug:
    msg:
      - "✅ ROSA service enablement completed:"
      - "  - Service was already enabled: {{ rosa_service_check.rc == 0 }}"
      - "  - Service auto-enabled: {{ rosa_service_auto_enabled | default(false) }}"
      - "  - Current status: {{ 'Enabled' if rosa_service_enabled else 'Requires Manual Setup' }}"
  tags:
    - aws
    - rosa-service

- name: "Provide manual enablement instructions"
  debug:
    msg:
      - "⚠️  ROSA service requires manual enablement:"
      - ""
      - "📋 Manual Steps Required:"
      - "  1. Visit: https://console.aws.amazon.com/rosa/home"
      - "  2. Click 'Enable OpenShift' button"
      - "  3. Review and accept the terms of service"
      - "  4. Complete the service enablement process"
      - "  5. Re-run this playbook after enablement"
      - ""
      - "🔗 Alternative: Run 'rosa whoami' and follow the prompts"
      - ""
      - "💡 This is a one-time setup per AWS account"
  when: not rosa_service_enabled
  tags:
    - aws
    - rosa-service

- name: "Fail if ROSA service is not enabled"
  fail:
    msg: |
      ❌ ROSA service is not enabled in your AWS account.
      
      Please visit https://console.aws.amazon.com/rosa/home to enable the service,
      then re-run this playbook.
      
      This is a one-time setup requirement per AWS account.
  when: 
    - not rosa_service_enabled
    - strict_validation | default(true)
  tags:
    - aws
    - rosa-service

- name: "Log ROSA service validation completion"
  debug:
    msg:
      - "✅ ROSA service validation completed successfully"
      - "  - Account: {{ ansible_env.AWS_PROFILE | default('default') }}"
      - "  - Region: {{ aws_region | default('us-east-1') }}"
      - "  - Service Status: Enabled"
  when: rosa_service_enabled
  tags:
    - aws
    - rosa-service
```

### Task 4 Key Features:
- **Service Detection**: Automatically checks if ROSA service is enabled
- **Auto-enablement**: Attempts to enable the service programmatically
- **Manual Instructions**: Provides clear steps if manual enablement is required
- **Graceful Handling**: Offers both strict and lenient validation modes
- **Comprehensive Logging**: Clear status reporting throughout the process

### Task 4 Integration Points:
- **Prerequisites**: Requires valid AWS credentials and ROSA CLI
- **Dependencies**: Must run after AWS CLI validation
- **Cluster Role**: Prevents cluster creation failures downstream
- **Error Handling**: Provides actionable error messages and next steps

## Step 7: Supporting Files

### Default Variables
**File to create**: `ansible/roles/aws-setup/defaults/main.yml`

```yaml
---
# Default variables for aws-setup role

# AWS Configuration
aws_region: "us-east-1"
aws_output_format: "json"

# Environment Configuration
target_environment: ""
terraform_base_path: "{{ playbook_dir }}/../terraform/environments"

# Installation Configuration
aws_cli_version: "2"
temp_dir: "/tmp"
```

### Role Variables
**File to create**: `ansible/roles/aws-setup/vars/main.yml`

```yaml
---
# Role-specific variables for aws-setup role

# AWS CLI Download URLs
aws_cli_linux_url: "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
aws_cli_macos_url: "https://awscli.amazonaws.com/AWSCLIV2.pkg"

# Valid environments
valid_environments:
  - dev
  - test
  - prod

# Required AWS policies for admin access
required_policies:
  - "AdministratorAccess"
  - "PowerUserAccess"
```

### Templates
**File to create**: `ansible/roles/aws-setup/templates/env.j2`

```bash
# Environment Configuration File
# Generated by Ansible aws-setup role

# Environment Information
ENVIRONMENT={{ target_environment }}
TERRAFORM_WORKSPACE={{ target_environment }}

# AWS Configuration (will be populated by ansible)
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
# AWS_DEFAULT_REGION=
# AWS_REGION=

# Project Configuration
PROJECT_NAME="ROSA-Infrastructure"
PROJECT_VERSION="1.0.0"

# Terraform Configuration
TF_VAR_environment={{ target_environment }}
TF_VAR_region={{ aws_region | default('us-east-1') }}
```

**File to create**: `ansible/roles/aws-setup/templates/export_env.sh.j2`

```bash
#!/bin/bash
# Environment Export Script
# Generated by Ansible aws-setup role

# Set AWS credentials
export AWS_ACCESS_KEY_ID="{{ aws_access_key_id }}"
export AWS_SECRET_ACCESS_KEY="{{ aws_secret_access_key }}"
export AWS_DEFAULT_REGION="{{ aws_region | default('us-east-1') }}"
export AWS_REGION="{{ aws_region | default('us-east-1') }}"

# Set environment variables
export ENVIRONMENT="{{ target_environment }}"
export TERRAFORM_WORKSPACE="{{ target_environment }}"

# Set project variables
export PROJECT_NAME="ROSA-Infrastructure"
export PROJECT_VERSION="1.0.0"

# Set Terraform variables
export TF_VAR_environment="{{ target_environment }}"
export TF_VAR_region="{{ aws_region | default('us-east-1') }}"

echo "Environment variables set for {{ target_environment }} environment"
echo "AWS Region: {{ aws_region | default('us-east-1') }}"
echo "Terraform workspace: {{ target_environment }}"
```

### Role Metadata
**File to create**: `ansible/roles/aws-setup/meta/main.yml`

```yaml
---
galaxy_info:
  author: DevOps Team
  description: AWS CLI setup and configuration validation role
  company: Consulting Firm
  license: MIT
  min_ansible_version: 2.9
  platforms:
    - name: Ubuntu
      versions:
        - bionic
        - focal
        - jammy
    - name: EL
      versions:
        - 7
        - 8
        - 9
    - name: MacOSX
      versions:
        - 10.15
        - 11.0
        - 12.0
  galaxy_tags:
    - aws
    - cli
    - setup
    - configuration
    - validation

dependencies: []
```

## Step 7: Testing the Role

### Test Playbook
**File to create**: `ansible/test_aws_setup.yml`

```yaml
---
- name: Test AWS Setup Role
  hosts: localhost
  connection: local
  gather_facts: yes
  
  roles:
    - aws-setup
  
  vars:
    aws_region: "us-east-1"
    target_environment: "dev"
```

### Running the Test (UPDATED)

> **⚠️ UPDATED**: Test commands now require AWS profile parameter

```bash
# Navigate to ansible directory
cd ansible/

# Run the test playbook with AWS profile
ansible-playbook test_aws_setup.yml --extra-vars "aws_profile=your-profile-name target_environment=dev aws_region=us-east-1"

# Run with specific environment and profile
ansible-playbook test_aws_setup.yml --extra-vars "aws_profile=production target_environment=prod aws_region=us-west-2"

# Run with verbose output
ansible-playbook test_aws_setup.yml --extra-vars "aws_profile=svktek target_environment=dev aws_region=us-east-1" -v

# Alternative: Set environment variable
AWS_PROFILE=your-profile-name ansible-playbook test_aws_setup.yml --extra-vars "target_environment=dev"
```

### Required Parameters (UPDATED)
| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `aws_profile` | AWS profile name | **Yes** | None |
| `target_environment` | Environment (dev/test/prod) | **Yes** | None |
| `aws_region` | AWS region | No | us-east-1 |

### Prerequisites (UPDATED)
- AWS CLI configured with named profiles
- AWS profile must have `AdministratorAccess` policy
- Profile credentials must be valid and not expired

## Step 8: Integration with Main Playbook

### Main Playbook Integration
**File to update**: `ansible/playbooks/main.yml`

```yaml
---
- name: ROSA Infrastructure Setup
  hosts: localhost
  connection: local
  gather_facts: yes
  
  pre_tasks:
    - name: Display playbook start
      debug:
        msg: "Starting ROSA infrastructure setup process"
  
  roles:
    - role: aws-setup
      tags: ['aws', 'setup']
    - role: rosa-cli
      tags: ['rosa', 'cli']
    - role: validation
      tags: ['validation', 'test']
  
  post_tasks:
    - name: Display playbook completion
      debug:
        msg: "ROSA infrastructure setup completed successfully"
```

## Step 9: Error Handling and Best Practices

### Error Handling Examples
```yaml
# Example: Robust error handling
- name: "Install AWS CLI with error handling"
  block:
    - name: "Download AWS CLI"
      get_url:
        url: "{{ aws_cli_linux_url }}"
        dest: "{{ temp_dir }}/awscliv2.zip"
        timeout: 30
  rescue:
    - name: "Handle download failure"
      debug:
        msg: "Failed to download AWS CLI. Please check internet connection."
    - name: "Fail with helpful message"
      fail:
        msg: "AWS CLI installation failed. Please install manually or check network connectivity."
  always:
    - name: "Clean up temporary files"
      file:
        path: "{{ temp_dir }}/awscliv2.zip"
        state: absent
```

### Security Best Practices
```yaml
# Example: Secure credential handling
- name: "Handle AWS credentials securely"
  set_fact:
    aws_access_key_id: "{{ lookup('env', 'AWS_ACCESS_KEY_ID') or aws_access_key_input.user_input }}"
    aws_secret_access_key: "{{ lookup('env', 'AWS_SECRET_ACCESS_KEY') or aws_secret_key_input.user_input }}"
  no_log: true
  
- name: "Validate credentials without logging"
  command: aws sts get-caller-identity
  register: aws_validation
  no_log: true
  changed_when: false
```

## Step 10: Troubleshooting Guide

### Common Issues and Solutions

1. **AWS CLI Installation Fails**
   - Check internet connectivity
   - Verify system architecture (x86_64)
   - Ensure sufficient disk space
   - Check for conflicting AWS CLI installations

2. **Service Account Validation Fails**
   - Verify AWS credentials are correct
   - Check IAM policy attachments
   - Ensure service account has required permissions
   - Verify account is not suspended

3. **Environment Setup Issues**
   - Check terraform directory structure
   - Verify file permissions
   - Ensure .env file is readable
   - Check environment variable exports

### Debug Mode
```bash
# Run with maximum verbosity
ansible-playbook test_aws_setup.yml -vvv

# Run specific tags
ansible-playbook test_aws_setup.yml --tags aws,setup

# Check syntax
ansible-playbook test_aws_setup.yml --syntax-check

# Dry run
ansible-playbook test_aws_setup.yml --check
```

## Step 11: AWS Profile Implementation (NEW)

### Security Enhancement: Profile-Based Authentication

The `aws-setup` role has been enhanced to use AWS profiles as the primary authentication method instead of hardcoded credentials. This provides:

#### Benefits:
- ✅ **Enhanced Security**: No plaintext credentials in playbooks
- ✅ **Profile Management**: Use existing AWS CLI profiles
- ✅ **Role-Based Access**: Leverage IAM roles and federated authentication
- ✅ **Audit Trail**: Better tracking of API calls per profile

#### Implementation Details:

**1. Profile Input Validation**
```yaml
- name: "Prompt for AWS profile name"
  pause:
    prompt: "Please enter your AWS profile name"
  register: aws_profile_input
  when: aws_profile is not defined

- name: "Validate AWS profile is provided"
  fail:
    msg: "AWS profile name is required"
  when: aws_profile is not defined or aws_profile == ""
```

**2. Environment Variable Management**
```yaml
- name: "Export AWS profile environment variable"
  shell: export AWS_PROFILE={{ aws_profile }}
  environment:
    AWS_PROFILE: "{{ aws_profile }}"
```

**3. Profile-Aware AWS Commands**
```yaml
- name: "Test AWS configuration"
  command: aws sts get-caller-identity
  environment:
    AWS_PROFILE: "{{ aws_profile }}"
```

### AWS Profile Setup Guide

#### 1. Configure AWS Profile
```bash
# Interactive configuration
aws configure --profile svktek

# Or manually edit ~/.aws/credentials
[svktek]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
region = us-east-1
output = json
```

#### 2. Verify Profile Configuration
```bash
# Test profile
aws sts get-caller-identity --profile svktek

# List available profiles
aws configure list-profiles
```

#### 3. Profile with IAM Roles (Advanced)
```bash
# ~/.aws/config
[profile svktek-role]
role_arn = arn:aws:iam::123456789012:role/AdminRole
source_profile = svktek
region = us-east-1
```

### Migration from Credential-Based Auth

#### Old Method (Deprecated)
```bash
ansible-playbook test_aws_setup.yml \
  -e aws_access_key_id=AKIA... \
  -e aws_secret_access_key=...
```

#### New Method (Recommended)
```bash
ansible-playbook test_aws_setup.yml \
  --extra-vars "aws_profile=svktek target_environment=dev"
```

## Conclusion

This learning module provides a comprehensive guide to building the `aws-setup` Ansible role. The role includes:

- ✅ AWS CLI installation and verification
- ✅ **AWS Profile-based authentication** (Enhanced Security)
- ✅ Service account validation with admin permission checks
- ✅ Environment setup and .env file management
- ✅ **ROSA service enablement and validation** 🚀 (NEW)
- ✅ Secure credential handling (No plaintext credentials)
- ✅ Cross-platform support (Linux, macOS)
- ✅ Comprehensive error handling
- ✅ Template-based configuration
- ✅ Integration with Terraform workflows
- ✅ **Profile management and validation**
- ✅ **Automated service prerequisite validation**

### Next Steps
1. Implement the files step by step
2. Test each task individually
3. Integrate with your existing playbooks
4. Add custom validations as needed
5. Document any project-specific requirements

### Learning Objectives Achieved
- Understanding Ansible role structure
- Implementing secure credential handling
- Creating reusable and modular Ansible tasks
- Integrating with external tools (AWS CLI, Terraform)
- Implementing proper error handling and validation