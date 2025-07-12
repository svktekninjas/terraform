# ROSA CLI Ansible Role - Learning Module

## Overview
This learning module provides step-by-step instructions for creating an Ansible role to manage ROSA (Red Hat OpenShift Service on AWS) CLI installation, authentication, and environment configuration.

## Prerequisites
- Basic understanding of Ansible roles and playbooks
- Access to a Red Hat account with ROSA permissions
- Linux/Unix environment for development

## Learning Objectives
By the end of this module, you will be able to:
1. Create a structured Ansible role for ROSA CLI management
2. Implement CLI installation and version checking
3. Handle secure authentication token management
4. Configure environment variables for different environments
5. Follow Ansible best practices for role development

## Module Structure

### Step 1: Create Role Directory Structure

First, create the basic Ansible role structure:

```bash
# Navigate to your ansible roles directory
cd /path/to/your/ansible/roles

# Create the role directory structure
mkdir -p rosa-cli/{defaults,vars,meta,tasks,files,templates,handlers}
```

**Key Concept**: Ansible roles follow a standardized directory structure that promotes reusability and maintainability.

### Step 2: Define Default Variables

Create `defaults/main.yml` to define configurable default values:

```yaml
---
# defaults/main.yml - User-configurable variables
rosa_cli_version: "latest"
rosa_cli_download_url: "https://mirror.openshift.com/pub/openshift-v4/clients/rosa/latest/rosa-linux.tar.gz"
rosa_cli_install_path: "/usr/local/bin"
rosa_cli_binary_name: "rosa"
rosa_auth_token: ""
environment: "dev"
terraform_env_path: "/absolute/path/to/terraform/environments"
```

**Best Practice**: Use absolute paths in variables to avoid path resolution issues.

### Step 3: Define Internal Variables

Create `vars/main.yml` for internal role variables:

```yaml
---
# vars/main.yml - Internal role variables (higher precedence than defaults)
rosa_cli_temp_dir: "/tmp/rosa-cli-install"
rosa_cli_archive_name: "rosa-linux.tar.gz"
env_file_name: "export_env.sh"
```

**Key Concept**: Variables in `vars/` have higher precedence than `defaults/` and are used for internal role logic.

### Step 4: Create Role Metadata

Create `meta/main.yml` to define role dependencies and information:

```yaml
---
galaxy_info:
  author: SRE Team
  description: ROSA CLI installation, authentication and configuration
  company: ConsultingFirm
  license: MIT
  min_ansible_version: 2.9

  platforms:
  - name: EL
    versions:
    - 8
    - 9
  - name: Ubuntu
    versions:
    - focal
    - jammy

  galaxy_tags:
    - rosa
    - openshift
    - aws
    - cli
    - redhat

dependencies: []
```

### Step 5: Create Main Tasks File

Create `tasks/main.yml` as the entry point:

```yaml
---
# tasks/main.yml - Main task orchestration
- name: Include check and install ROSA CLI task
  include_tasks: check_install_rosa_cli.yml
  tags:
    - rosa-cli-install
    - rosa-setup

- name: Include ROSA authentication task
  include_tasks: rosa_authentication.yml
  tags:
    - rosa-auth
    - rosa-setup

- name: Include environment configuration task
  include_tasks: configure_environment.yml
  tags:
    - rosa-env
    - rosa-setup
```

**Best Practice**: Use `include_tasks` to modularize complex roles and apply meaningful tags for selective execution.

### Step 6: Implement ROSA CLI Installation Task

Create `tasks/check_install_rosa_cli.yml`:

```yaml
---
# Task 1: Check if ROSA CLI is installed and up to date version
- name: Check if ROSA CLI is installed
  shell: "which {{ rosa_cli_binary_name }}"
  register: rosa_cli_check
  ignore_errors: true
  changed_when: false

- name: Get current ROSA CLI version if installed
  shell: "{{ rosa_cli_binary_name }} version --output=json"
  register: rosa_current_version
  ignore_errors: true
  changed_when: false
  when: rosa_cli_check.rc == 0

- name: Create temporary directory for ROSA CLI installation
  file:
    path: "{{ rosa_cli_temp_dir }}"
    state: directory
    mode: '0755'
  when: rosa_cli_check.rc != 0 or rosa_cli_version != "latest"

- name: Download latest ROSA CLI version info
  uri:
    url: "https://api.github.com/repos/openshift/rosa/releases/latest"
    method: GET
    return_content: yes
  register: rosa_latest_release
  when: rosa_cli_check.rc != 0 or rosa_cli_version != "latest"

- name: Set latest version fact
  set_fact:
    rosa_latest_version: "{{ rosa_latest_release.json.tag_name }}"
  when: rosa_cli_check.rc != 0 or rosa_cli_version != "latest"

- name: Check if update is needed
  set_fact:
    rosa_needs_update: true
  when: >
    rosa_cli_check.rc != 0 or 
    (rosa_current_version.stdout is defined and 
     rosa_current_version.stdout | from_json | json_query('releaseVersion') != rosa_latest_version)

- name: Download ROSA CLI archive
  get_url:
    url: "{{ rosa_cli_download_url }}"
    dest: "{{ rosa_cli_temp_dir }}/{{ rosa_cli_archive_name }}"
    mode: '0644'
  when: rosa_needs_update | default(false)

- name: Extract ROSA CLI archive
  unarchive:
    src: "{{ rosa_cli_temp_dir }}/{{ rosa_cli_archive_name }}"
    dest: "{{ rosa_cli_temp_dir }}"
    remote_src: yes
  when: rosa_needs_update | default(false)

- name: Install/Update ROSA CLI binary
  copy:
    src: "{{ rosa_cli_temp_dir }}/rosa"
    dest: "{{ rosa_cli_install_path }}/{{ rosa_cli_binary_name }}"
    mode: '0755'
    remote_src: yes
  become: yes
  when: rosa_needs_update | default(false)

- name: Verify ROSA CLI installation
  shell: "{{ rosa_cli_binary_name }} version"
  register: rosa_verify_install
  changed_when: false

- name: Display ROSA CLI version
  debug:
    msg: "ROSA CLI version: {{ rosa_verify_install.stdout }}"

- name: Clean up temporary directory
  file:
    path: "{{ rosa_cli_temp_dir }}"
    state: absent
  when: rosa_needs_update | default(false)
```

**Key Concepts Demonstrated**:
- **Idempotency**: Tasks only run when changes are needed
- **Error Handling**: Using `ignore_errors` and conditional execution
- **Fact Setting**: Using `set_fact` to store computed values
- **Privilege Escalation**: Using `become` for system-level operations

### Step 7: Implement Authentication Task

Create `tasks/rosa_authentication.yml`:

```yaml
---
# Task 2: Request user to enter ROSA auth token, perform login and validate token
# 
# Instructions to acquire ROSA auth token:
# 1. Visit https://console.redhat.com/openshift/token/rosa
# 2. Log in with your Red Hat account credentials
# 3. Click "Load token" or "Copy token" button
# 4. Copy the token string that appears
# 5. Paste it when prompted by this playbook
# 
# Alternative method:
# 1. Go to https://cloud.redhat.com/openshift/token
# 2. Select "ROSA" from the dropdown
# 3. Copy the token provided
#
# Note: The token is valid for 24 hours and provides CLI access to your ROSA resources

- name: Prompt user for ROSA auth token
  pause:
    prompt: "Please enter your ROSA authentication token (from https://console.redhat.com/openshift/token/rosa)"
    echo: no
  register: rosa_token_input
  when: rosa_auth_token == ""

- name: Set ROSA auth token from user input
  set_fact:
    rosa_auth_token: "{{ rosa_token_input.user_input }}"
  when: rosa_auth_token == "" and rosa_token_input.user_input is defined

- name: Validate ROSA auth token is provided
  fail:
    msg: "ROSA authentication token is required to proceed"
  when: rosa_auth_token == ""

- name: Perform ROSA login
  shell: "{{ rosa_cli_binary_name }} login --token={{ rosa_auth_token }}"
  register: rosa_login_result
  no_log: true
  ignore_errors: true

- name: Check if ROSA login was successful
  fail:
    msg: "ROSA login failed. Please verify your authentication token. Error: {{ rosa_login_result.stderr }}"
  when: rosa_login_result.rc != 0

- name: Verify ROSA authentication
  shell: "{{ rosa_cli_binary_name }} whoami"
  register: rosa_whoami_result
  changed_when: false

- name: Display ROSA authentication status
  debug:
    msg: "Successfully authenticated to ROSA as: {{ rosa_whoami_result.stdout }}"
  when: rosa_whoami_result.rc == 0

- name: Verify ROSA permissions
  shell: "{{ rosa_cli_binary_name }} verify permissions"
  register: rosa_permissions_check
  ignore_errors: true
  changed_when: false

- name: Display ROSA permissions status
  debug:
    msg: "ROSA permissions verification: {{ 'PASSED' if rosa_permissions_check.rc == 0 else 'FAILED - Some permissions may be missing' }}"

- name: Store ROSA auth token for environment configuration
  set_fact:
    validated_rosa_token: "{{ rosa_auth_token }}"
```

**Security Best Practices Demonstrated**:
- **No Logging**: Using `no_log: true` to prevent sensitive data in logs
- **User Interaction**: Using `pause` module for secure token input
- **Validation**: Comprehensive error checking and verification

### Step 8: Implement Environment Configuration Task

Create `tasks/configure_environment.yml`:

```yaml
---
# Task 3: Create ROSA auth token variable and update .env file in terraform/environments folder
- name: Prompt user for environment (dev/test/prod)
  pause:
    prompt: "Please enter the target environment (dev/test/prod)"
  register: environment_input
  when: environment == ""

- name: Set environment from user input
  set_fact:
    environment: "{{ environment_input.user_input | lower }}"
  when: environment == "" and environment_input.user_input is defined

- name: Validate environment input
  fail:
    msg: "Environment must be one of: dev, test, prod"
  when: environment not in ['dev', 'test', 'prod']

- name: Set environment file path
  set_fact:
    env_file_path: "{{ terraform_env_path }}/{{ environment }}/{{ env_file_name }}"

- name: Check if environment directory exists
  stat:
    path: "{{ terraform_env_path }}/{{ environment }}"
  register: env_dir_check

- name: Create environment directory if it doesn't exist
  file:
    path: "{{ terraform_env_path }}/{{ environment }}"
    state: directory
    mode: '0755'
  when: not env_dir_check.stat.exists

- name: Check if environment file exists
  stat:
    path: "{{ env_file_path }}"
  register: env_file_check

- name: Read existing environment file content
  slurp:
    src: "{{ env_file_path }}"
  register: existing_env_content
  when: env_file_check.stat.exists

- name: Decode existing environment content
  set_fact:
    current_env_lines: "{{ (existing_env_content.content | b64decode).split('\n') }}"
  when: env_file_check.stat.exists

- name: Filter out existing ROSA token entries
  set_fact:
    filtered_env_lines: "{{ current_env_lines | reject('match', '^export ROSA_TOKEN=.*') | reject('match', '^export TF_VAR_rosa_token=.*') | list }}"
  when: env_file_check.stat.exists

- name: Add ROSA token environment variables
  set_fact:
    updated_env_lines: "{{ (filtered_env_lines | default([])) + rosa_env_additions }}"
  vars:
    rosa_env_additions:
      - ""
      - "# ROSA CLI authentication token"
      - "export ROSA_TOKEN=\"{{ validated_rosa_token }}\""
      - "export TF_VAR_rosa_token=\"{{ validated_rosa_token }}\""

- name: Create/Update environment file with ROSA token
  copy:
    content: |
      {% if not env_file_check.stat.exists %}
      #!/bin/bash
      # Environment Export Script
      # Generated by Ansible rosa-cli role
      
      # Set AWS profile
      export AWS_PROFILE="svktek"
      export AWS_DEFAULT_REGION="us-east-1"
      export AWS_REGION="us-east-1"
      
      # Set environment variables
      export ENVIRONMENT="{{ environment }}"
      export TERRAFORM_WORKSPACE="{{ environment }}"
      
      # Set project variables
      export PROJECT_NAME="ROSA-Infrastructure"
      export PROJECT_VERSION="1.0.0"
      
      # Set Terraform variables
      export TF_VAR_environment="{{ environment }}"
      export TF_VAR_region="us-east-1"
      {% endif %}
      {{ updated_env_lines | join('\n') }}
      {% if not env_file_check.stat.exists %}
      
      echo "Environment variables set for {{ environment }} environment"
      echo "AWS Region: us-east-1"
      echo "Terraform workspace: {{ environment }}"
      echo "ROSA token configured"
      {% endif %}
    dest: "{{ env_file_path }}"
    mode: '0755'
    backup: yes

- name: Display environment configuration status
  debug:
    msg: |
      ROSA CLI environment configuration completed:
      - Environment: {{ environment }}
      - Config file: {{ env_file_path }}
      - ROSA token added to environment variables
      
      To use the environment variables, run:
      source {{ env_file_path }}

- name: Verify environment file was created/updated
  stat:
    path: "{{ env_file_path }}"
  register: final_env_check

- name: Confirm successful configuration
  debug:
    msg: "✓ ROSA CLI role configuration completed successfully"
  when: final_env_check.stat.exists
```

**Advanced Concepts Demonstrated**:
- **File Manipulation**: Reading, filtering, and updating existing files
- **Jinja2 Templating**: Using templates for dynamic content generation
- **List Processing**: Using filters like `reject()` and `join()`
- **Backup Strategy**: Using `backup: yes` for safe file modifications

## Usage Examples

### Example Playbook

Create a playbook to use the role:

```yaml
---
# playbooks/rosa-setup.yml
- name: Setup ROSA CLI
  hosts: localhost
  gather_facts: yes
  vars:
    environment: "{{ env | default('dev') }}"
    terraform_env_path: "/absolute/path/to/terraform/environments"
  
  roles:
    - role: rosa-cli
      tags: rosa-setup
```

### Running the Playbook

```bash
# Run with default environment (dev)
ansible-playbook playbooks/rosa-setup.yml

# Run with specific environment
ansible-playbook playbooks/rosa-setup.yml -e "env=prod"

# Run only specific tasks
ansible-playbook playbooks/rosa-setup.yml --tags rosa-cli-install

# Skip authentication if already logged in
ansible-playbook playbooks/rosa-setup.yml --skip-tags rosa-auth
```

## Key Learning Points

### 1. Ansible Role Best Practices
- **Modularity**: Break complex tasks into separate files
- **Idempotency**: Ensure tasks can run multiple times safely
- **Variables**: Use defaults for configuration, vars for internal logic
- **Tags**: Allow selective execution of role components

### 2. Security Considerations
- **Sensitive Data**: Use `no_log` for credentials
- **File Permissions**: Set appropriate permissions for scripts and configs
- **Token Management**: Store tokens securely and temporarily

### 3. Error Handling
- **Validation**: Check inputs and prerequisites before proceeding
- **Graceful Failures**: Provide meaningful error messages
- **Cleanup**: Remove temporary files and directories

### 4. Path Management
- **Absolute Paths**: Always use absolute paths in variables
- **Path Variables**: Make paths configurable for different environments
- **Directory Creation**: Ensure parent directories exist before file operations

## Common Pitfalls and Solutions

### 1. Path Issues
**Problem**: Relative paths causing failures in different execution contexts
**Solution**: Use absolute paths stored in variables

### 2. Token Security
**Problem**: Tokens appearing in logs or being stored insecurely
**Solution**: Use `no_log: true` and secure file permissions

### 3. Idempotency
**Problem**: Tasks running unnecessarily on subsequent executions
**Solution**: Implement proper condition checks and use `changed_when`

### 4. Error Messages
**Problem**: Cryptic error messages making troubleshooting difficult
**Solution**: Provide clear, actionable error messages with context

## Extension Exercises

1. **Add Version Pinning**: Modify the role to install a specific ROSA CLI version
2. **Multi-OS Support**: Add support for macOS and different Linux distributions
3. **Configuration Validation**: Add tasks to validate ROSA configuration
4. **Cleanup Tasks**: Create tasks to remove ROSA CLI and clean up configurations
5. **Logging Enhancement**: Add comprehensive logging for troubleshooting

## Conclusion

This learning module demonstrates professional Ansible role development practices for ROSA CLI management. The modular approach, comprehensive error handling, and security considerations shown here can be applied to other infrastructure automation tasks.

Remember to test your roles thoroughly in development environments before applying them to production systems.