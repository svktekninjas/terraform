# ROSA CLI Ansible Role - Learning Module

## Overview
This learning module provides step-by-step instructions for creating an Ansible role to manage ROSA (Red Hat OpenShift Service on AWS) CLI installation, authentication, and environment configuration.

> **Updated**: This guide includes production-tested fixes for ROSA CLI version checking, environment variable conflicts, and selective environment file updates.

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
environment: "dev"  # Note: Use target_environment in CLI to avoid conflicts
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
  tags: rosa

- name: Get current ROSA CLI version if installed
  shell: "{{ rosa_cli_binary_name }} version --client"
  register: rosa_current_version
  ignore_errors: true
  changed_when: false
  when: rosa_cli_check.rc == 0
  tags: rosa

- name: Create temporary directory for ROSA CLI installation
  file:
    path: "{{ rosa_cli_temp_dir }}"
    state: directory
    mode: '0755'
  when: rosa_cli_check.rc != 0 or rosa_cli_version != "latest"
  tags: rosa

- name: Download latest ROSA CLI version info
  uri:
    url: "https://api.github.com/repos/openshift/rosa/releases/latest"
    method: GET
    return_content: yes
  register: rosa_latest_release
  when: rosa_cli_check.rc != 0 or rosa_cli_version != "latest"
  tags: rosa

- name: Set latest version fact
  set_fact:
    rosa_latest_version: "{{ rosa_latest_release.json.tag_name }}"
  when: rosa_cli_check.rc != 0 or rosa_cli_version != "latest"
  tags: rosa

- name: Check if update is needed
  set_fact:
    rosa_needs_update: true
  when: >
    rosa_cli_check.rc != 0 or 
    (rosa_cli_version != "latest" and rosa_current_version.stdout is defined and
     rosa_latest_version is defined and rosa_latest_version not in rosa_current_version.stdout)
  tags: rosa

- name: Download ROSA CLI archive
  get_url:
    url: "{{ rosa_cli_download_url }}"
    dest: "{{ rosa_cli_temp_dir }}/{{ rosa_cli_archive_name }}"
    mode: '0644'
  when: rosa_needs_update | default(false)
  tags: rosa

- name: Extract ROSA CLI archive
  unarchive:
    src: "{{ rosa_cli_temp_dir }}/{{ rosa_cli_archive_name }}"
    dest: "{{ rosa_cli_temp_dir }}"
    remote_src: yes
  when: rosa_needs_update | default(false)
  tags: rosa

- name: Install/Update ROSA CLI binary
  copy:
    src: "{{ rosa_cli_temp_dir }}/rosa"
    dest: "{{ rosa_cli_install_path }}/{{ rosa_cli_binary_name }}"
    mode: '0755'
    remote_src: yes
  become: yes
  when: rosa_needs_update | default(false)
  tags: rosa

- name: Verify ROSA CLI installation
  shell: "{{ rosa_cli_binary_name }} version"
  register: rosa_verify_install
  changed_when: false
  tags: rosa

- name: Display ROSA CLI version
  debug:
    msg: "ROSA CLI version: {{ rosa_verify_install.stdout }}"
  tags: rosa

- name: Clean up temporary directory
  file:
    path: "{{ rosa_cli_temp_dir }}"
    state: absent
  when: rosa_needs_update | default(false)
  tags: rosa
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
- name: Set target environment variable
  set_fact:
    target_env: "{{ target_environment | default(environment | default('')) }}"
  tags: rosa

- name: Prompt user for environment (dev/test/prod)
  pause:
    prompt: "Please enter the target environment (dev/test/prod)"
  register: environment_input
  when: target_env == ""
  tags: rosa

- name: Set environment from user input
  set_fact:
    target_env: "{{ environment_input.user_input | lower }}"
  when: target_env == "" and environment_input.user_input is defined
  tags: rosa

- name: Validate environment input
  fail:
    msg: "Environment must be one of: dev, test, prod"
  when: target_env not in ['dev', 'test', 'prod']
  tags: rosa

- name: Set environment file path
  set_fact:
    env_file_path: "{{ terraform_env_path }}/{{ target_env }}/{{ env_file_name }}"
  tags: rosa

- name: Check if environment directory exists
  stat:
    path: "{{ terraform_env_path }}/{{ target_env }}"
  register: env_dir_check
  tags: rosa

- name: Create environment directory if it doesn't exist
  file:
    path: "{{ terraform_env_path }}/{{ target_env }}"
    state: directory
    mode: '0755'
  when: not env_dir_check.stat.exists
  tags: rosa

- name: Check if environment file exists
  stat:
    path: "{{ env_file_path }}"
  register: env_file_check
  tags: rosa

- name: Ensure environment file exists (should be created by aws-setup role)
  fail:
    msg: "Environment file {{ env_file_path }} does not exist. Please run aws-setup role first."
  when: not env_file_check.stat.exists

- name: Update environment file with ROSA token only
  blockinfile:
    path: "{{ env_file_path }}"
    block: |
      # ROSA CLI authentication token
      export ROSA_TOKEN="{{ validated_rosa_token }}"
      export TF_VAR_rosa_token="{{ validated_rosa_token }}"
    marker: "# {mark} ANSIBLE MANAGED ROSA BLOCK"
    backup: yes
    create: no

- name: Display environment configuration status
  debug:
    msg: |
      ROSA CLI environment configuration completed:
      - Environment: {{ target_env }}
      - Config file: {{ env_file_path }}
      - ROSA token added to existing environment file (AWS settings preserved)
      
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
- **Role Dependencies**: Ensuring aws-setup role runs first to create environment file
- **Selective File Updates**: Using `blockinfile` to update only ROSA-specific sections
- **Configuration Preservation**: Maintaining existing AWS settings while adding ROSA tokens
- **Backup Strategy**: Using `backup: yes` for safe file modifications
- **Dependency Validation**: Checking prerequisites before proceeding

## Usage Examples

### Example Playbook

Create a playbook to use the role with proper dependencies:

```yaml
---
# playbooks/rosa-setup.yml
- name: Setup ROSA Infrastructure
  hosts: localhost
  gather_facts: yes
  
  roles:
    # AWS setup must run first to create environment file
    - role: aws-setup
      tags: ['aws', 'setup']
    # ROSA CLI depends on aws-setup role
    - role: rosa-cli
      tags: ['rosa', 'cli']
```

### Running the Playbook

```bash
# Run complete setup (AWS + ROSA) - Recommended
ansible-playbook playbooks/rosa-setup.yml -e target_environment=dev -e aws_profile=your-profile -e rosa_auth_token="your-token"

# Run only ROSA CLI setup (requires aws-setup to have run first)
ansible-playbook playbooks/rosa-setup.yml --tags rosa -e target_environment=dev -e rosa_auth_token="your-token"

# Run only specific ROSA tasks
ansible-playbook playbooks/rosa-setup.yml --tags rosa-cli-install
ansible-playbook playbooks/rosa-setup.yml --tags rosa-auth -e rosa_auth_token="your-token"

# Skip authentication if already logged in
ansible-playbook playbooks/rosa-setup.yml --skip-tags rosa-auth -e target_environment=dev
```

### Required Variables

**For ROSA CLI Role Only:**
- `target_environment`: Target environment (dev/test/prod)
- `rosa_auth_token`: ROSA authentication token

**Important**: The aws-setup role must run first to create the environment file structure.

**Note**: Use `target_environment` instead of `environment` to avoid conflicts with Ansible's built-in environment variable.

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

### 5. Variable Naming
- **Reserved Names**: Avoid using Ansible reserved variable names like `environment`
- **Namespace Variables**: Use prefixed variable names like `target_environment` to avoid conflicts
- **Variable Precedence**: Understand default vs vars vs command-line variable precedence

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

### 5. Variable Naming Conflicts
**Problem**: Using `environment` variable conflicts with Ansible's built-in environment variable
**Solution**: Use alternative names like `target_environment` or `env_name` to avoid conflicts

### 6. ROSA CLI Version Checking
**Problem**: ROSA CLI doesn't support `--output=json` flag for version command
**Solution**: Use `--client` flag and parse plain text output instead of JSON

## Extension Exercises

1. **Add Version Pinning**: Modify the role to install a specific ROSA CLI version
2. **Multi-OS Support**: Add support for macOS and different Linux distributions
3. **Configuration Validation**: Add tasks to validate ROSA configuration
4. **Cleanup Tasks**: Create tasks to remove ROSA CLI and clean up configurations
5. **Logging Enhancement**: Add comprehensive logging for troubleshooting

## Conclusion

This learning module demonstrates professional Ansible role development practices for ROSA CLI management. The modular approach, comprehensive error handling, and security considerations shown here can be applied to other infrastructure automation tasks.

Remember to test your roles thoroughly in development environments before applying them to production systems.