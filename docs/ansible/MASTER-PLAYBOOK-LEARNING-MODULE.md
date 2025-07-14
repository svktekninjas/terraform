# Master Playbook Learning Module - ROSA Infrastructure Setup

## Overview
This learning module teaches you how to create and manage a master Ansible playbook that orchestrates multiple roles for ROSA (Red Hat OpenShift Service on AWS) infrastructure setup. The master playbook coordinates AWS setup, ROSA CLI configuration, and validation tasks.

## Learning Objectives
By completing this module, you will learn to:
1. Design master playbooks that coordinate multiple roles
2. Implement role dependencies and execution order
3. Use tags for selective role execution
4. Handle cross-role variable passing
5. Implement comprehensive error handling and logging
6. Create flexible playbooks for different environments

## Master Playbook Architecture

### Role Execution Order (Critical Dependencies)
```
Master Playbook
├── Pre-tasks (Initialization)
├── 1. aws-setup role (MUST run first)
│   ├── Install AWS CLI
│   ├── Validate service account
│   ├── Setup environment variables
│   └── Create .env file in ansible/environments/{env}/
├── 2. rosa-cli role (Depends on aws-setup)
│   ├── Install/Update ROSA CLI
│   ├── Handle authentication
│   ├── Configure environment
│   └── Add ROSA_TOKEN to .env file
├── 3. validation role (Depends on aws-setup + rosa-cli)
│   ├── Validate AWS region support
│   ├── Validate availability zones
│   ├── Validate cluster configuration
│   ├── Validate AWS quotas
│   └── Validate ROSA prerequisites
└── Post-tasks (Cleanup & Summary)
```

**Critical:** The validation role requires AWS CLI and ROSA CLI to be properly configured, so it MUST run after aws-setup and rosa-cli roles.

## Step-by-Step Implementation

### Step 1: Create Master Playbook Structure

```yaml
---
# playbooks/main.yml - Master ROSA Infrastructure Setup Playbook
- name: ROSA Infrastructure Setup
  hosts: localhost
  connection: local
  gather_facts: yes
  
  # Global variables available to all roles
  vars:
    # Environment configuration
    target_environment: "{{ environment | default('dev') }}"
    ansible_env_path: "{{ playbook_dir }}/../environments/{{ target_environment }}"
    
    # AWS configuration
    aws_region: "{{ region | default('us-east-1') }}"
    aws_profile: "{{ profile | default('svktek') }}"
    
    # ROSA configuration
    rosa_cli_install_path: "/usr/local/bin"
  
  # Initialization tasks
  pre_tasks:
    - name: Display playbook start
      debug:
        msg: |
          Starting ROSA infrastructure setup process
          Environment: {{ target_environment }}
          AWS Region: {{ aws_region }}
          AWS Profile: {{ aws_profile }}
    
    - name: Validate required variables
      fail:
        msg: "{{ item }} is required but not provided"
      when: vars[item] is undefined or vars[item] == ""
      loop:
        - target_environment
        - aws_region
      tags: always
    
    - name: Create logs directory
      file:
        path: "{{ playbook_dir }}/../logs"
        state: directory
        mode: '0755'
      tags: always
  
  # Role execution with correct dependency order
  roles:
    - role: aws-setup
      vars:
        target_environment: "{{ target_environment }}"
        aws_region: "{{ aws_region }}"
        aws_profile: "{{ aws_profile }}"
      tags: ['aws', 'setup', 'infrastructure']
      
    - role: rosa-cli
      vars:
        target_environment: "{{ target_environment }}"
        rosa_cli_install_path: "{{ rosa_cli_install_path }}"
      tags: ['rosa', 'cli', 'authentication']
      
    - role: validation
      vars:
        environment_name: "{{ target_environment }}"
        aws_region: "{{ aws_region }}"
      tags: ['validation', 'pre-checks', 'verify']
  
  # Cleanup and summary tasks
  post_tasks:
    - name: Generate setup summary
      template:
        src: "{{ playbook_dir }}/../roles/templates/setup_summary.j2"
        dest: "{{ playbook_dir }}/../logs/rosa_setup_{{ target_environment }}_{{ ansible_date_time.epoch }}.log"
        mode: '0644'
      tags: always
    
    - name: Display playbook completion
      debug:
        msg: |
          ✅ ROSA infrastructure setup completed successfully!
          
          Summary:
          - Environment: {{ target_environment }}
          - AWS Region: {{ aws_region }}
          - Ansible Config Path: {{ ansible_env_path }}
          
          Next Steps:
          1. Source environment variables: source {{ ansible_env_path }}/.env
          2. Verify setup: ansible-playbook playbooks/main.yml --tags validation -e @environments/{{ target_environment }}/{{ target_environment }}.yml
          3. Deploy infrastructure with validated configuration
      tags: always
```

### Step 2: Advanced Playbook Features

#### Error Handling and Recovery
```yaml
# Add to pre_tasks section
- name: Setup error handling
  block:
    - name: Check disk space
      shell: df -h {{ ansible_env.HOME }} | tail -n1 | awk '{print $5}' | sed 's/%//'
      register: disk_usage
      
    - name: Fail if insufficient disk space
      fail:
        msg: "Insufficient disk space. Current usage: {{ disk_usage.stdout }}%"
      when: disk_usage.stdout | int > 90
      
  rescue:
    - name: Cleanup on error
      file:
        path: "{{ item }}"
        state: absent
      loop:
        - "/tmp/rosa-cli-install"
        - "/tmp/aws-cli-install"
      ignore_errors: yes
      
    - name: Log error details
      copy:
        content: |
          Error occurred at: {{ ansible_date_time.iso8601 }}
          Failed task: {{ ansible_failed_task.name | default('Unknown') }}
          Error message: {{ ansible_failed_result.msg | default('No message') }}
        dest: "{{ playbook_dir }}/../logs/error_{{ ansible_date_time.epoch }}.log"
```

#### Dynamic Role Selection
```yaml
# Add conditional role execution
- role: aws-setup
  when: setup_aws | default(true) | bool
  
- role: rosa-cli
  when: setup_rosa | default(true) | bool
  
- role: validation
  when: run_validation | default(true) | bool
```

#### Cross-Role Variable Passing
```yaml
# In roles section, pass outputs from one role to another
- role: aws-setup
  vars:
    target_environment: "{{ target_environment }}"
  register: aws_setup_result
  
- role: rosa-cli
  vars:
    environment: "{{ target_environment }}"
    aws_profile: "{{ aws_setup_result.aws_profile | default(aws_profile) }}"
  when: aws_setup_result is succeeded
```

### Step 3: Advanced Tagging Strategy

```yaml
# Comprehensive tagging for selective execution
roles:
  - role: aws-setup
    tags: 
      - infrastructure
      - aws
      - setup
      - prereq
      - never-skip  # Always runs unless explicitly skipped
      
  - role: rosa-cli
    tags:
      - application
      - rosa
      - cli
      - auth
      - openshift
      
  - role: validation
    tags:
      - testing
      - validation
      - verify
      - post-setup
      - optional  # Can be skipped
```

### Step 4: Environment-Specific Configuration

```yaml
# Add environment-specific variable files
- name: Load environment-specific variables
  include_vars: "{{ item }}"
  with_first_found:
    - files:
        - "{{ playbook_dir }}/vars/{{ target_environment }}.yml"
        - "{{ playbook_dir }}/vars/default.yml"
  tags: always

# Create vars/dev.yml, vars/test.yml, vars/prod.yml
# Example vars/prod.yml:
---
aws_region: "us-west-2"
rosa_cli_version: "1.2.25"
validation_strict: true
backup_enabled: true
```

### Step 5: Parallel Execution Support

```yaml
# For independent tasks, use async execution
- name: Run independent validations
  include_role:
    name: validation
    tasks_from: "{{ item }}"
  async: 300
  poll: 0
  register: validation_jobs
  loop:
    - check_aws_permissions
    - check_network_connectivity
    - check_dns_resolution
  tags: validation

- name: Wait for validation jobs
  async_status:
    jid: "{{ item.ansible_job_id }}"
  register: job_result
  until: job_result.finished
  retries: 30
  delay: 10
  loop: "{{ validation_jobs.results }}"
  tags: validation
```

### Step 6: Logging and Monitoring

```yaml
# Add comprehensive logging
- name: Setup execution logging
  lineinfile:
    path: "{{ playbook_dir }}/../logs/execution.log"
    line: |
      {{ ansible_date_time.iso8601 }} - START - {{ inventory_hostname }} - {{ target_environment }}
    create: yes
  tags: always

# Add role-specific logging
- role: aws-setup
  vars:
    log_file: "{{ playbook_dir }}/../logs/aws_setup_{{ ansible_date_time.epoch }}.log"
```

## Key Learning Concepts

### 1. Playbook Design Patterns

#### Sequential Dependencies
```yaml
# When roles must run in specific order
roles:
  - { role: aws-setup, tags: ['phase1'] }
  - { role: rosa-cli, tags: ['phase2'] }
  - { role: validation, tags: ['phase3'] }
```

#### Conditional Dependencies
```yaml
# When roles depend on conditions
- role: rosa-cli
  when: aws_setup_complete is defined and aws_setup_complete
```

#### Parallel Safe Roles
```yaml
# When roles can run independently
- include_role:
    name: monitoring
  async: 600
  poll: 0
  
- include_role:
    name: logging
  async: 600
  poll: 0
```

### 2. Variable Management Best Practices

#### Variable Precedence (highest to lowest)
1. Command line `-e` variables
2. Role `vars/main.yml`
3. Playbook `vars` section
4. Host/Group variables
5. Role `defaults/main.yml`

#### Variable Scope
```yaml
# Global scope - available to all roles
vars:
  global_config: "value"

# Role scope - only available within role
roles:
  - role: aws-setup
    vars:
      role_specific: "value"
```

### 3. Error Handling Strategies

#### Graceful Failures
```yaml
- role: optional-role
  ignore_errors: yes
  register: optional_result
  
- debug:
    msg: "Optional role failed but continuing: {{ optional_result.msg }}"
  when: optional_result is failed
```

#### Rollback Procedures
```yaml
rescue:
  - name: Rollback configuration
    include_tasks: rollback.yml
    vars:
      rollback_target: "{{ target_environment }}"
```

## Common Patterns and Anti-Patterns

### ✅ Good Practices

#### Clear Role Separation
```yaml
# Each role has a single responsibility
- role: aws-setup      # Only AWS configuration
- role: rosa-cli       # Only ROSA CLI management
- role: validation     # Only testing and validation
```

#### Meaningful Tags
```yaml
tags: ['infrastructure', 'aws', 'prereq']  # Descriptive and hierarchical
```

#### Variable Validation
```yaml
pre_tasks:
  - name: Validate required variables
    assert:
      that:
        - target_environment in ['dev', 'test', 'prod']
        - aws_region is match('^[a-z]{2}-[a-z]+-[0-9]$')
```

### ❌ Anti-Patterns to Avoid

#### Hardcoded Values
```yaml
# Bad
vars:
  aws_region: "us-east-1"  # Hardcoded

# Good
vars:
  aws_region: "{{ region | default('us-east-1') }}"  # Configurable
```

#### Role Coupling
```yaml
# Bad - roles directly accessing each other's variables
- role: rosa-cli
  vars:
    aws_profile: "{{ aws_setup_aws_profile }}"  # Tight coupling

# Good - explicit variable passing
- role: rosa-cli
  vars:
    aws_profile: "{{ aws_setup_result.aws_profile }}"  # Explicit dependency
```

## Testing and Validation

### Syntax Validation
```bash
# Check playbook syntax
ansible-playbook playbooks/main.yml --syntax-check

# Check role syntax individually
ansible-playbook playbooks/main.yml --syntax-check --tags aws-setup
```

### Dry Run Testing
```bash
# Test without making changes
ansible-playbook playbooks/main.yml --check --diff

# Test specific roles
ansible-playbook playbooks/main.yml --check --tags rosa-cli
```

### Environment Testing
```bash
# Test in different environments
ansible-playbook playbooks/main.yml -e "environment=dev" --check
ansible-playbook playbooks/main.yml -e "environment=test" --check
```

## Advanced Topics

### 1. Dynamic Inventory Integration
```yaml
# Support for dynamic environments
- name: Load dynamic configuration
  set_fact:
    target_environment: "{{ lookup('env', 'ROSA_ENV') | default('dev') }}"
    aws_region: "{{ lookup('env', 'AWS_REGION') | default('us-east-1') }}"
```

### 2. Secrets Management
```yaml
# Integration with external secret management
- name: Load secrets from vault
  include_vars: "{{ lookup('hashivault', 'secret/rosa/' + target_environment) }}"
  no_log: true
```

### 3. Multi-Environment Deployment
```yaml
# Support for multiple environments in single run
- name: Deploy to multiple environments
  include: main.yml
  vars:
    target_environment: "{{ item }}"
  loop: "{{ deploy_environments | default(['dev']) }}"
```

## Exercises

### Exercise 1: Basic Master Playbook
Create a simple master playbook that runs aws-setup and rosa-cli roles sequentially.

### Exercise 2: Tag-Based Execution
Modify the playbook to support running only infrastructure setup or only CLI configuration.

### Exercise 3: Environment Variables
Add support for loading environment-specific configuration files.

### Exercise 4: Error Recovery
Implement error handling that can recover from common failures.

### Exercise 5: Parallel Execution
Modify independent tasks to run in parallel for better performance.

## Conclusion

Master playbooks are the orchestration layer that ties together multiple Ansible roles to achieve complex infrastructure setups. Key principles include:

- **Modularity**: Each role has a single, clear responsibility
- **Flexibility**: Support for different environments and execution modes
- **Reliability**: Comprehensive error handling and validation
- **Maintainability**: Clear structure and documentation
- **Observability**: Proper logging and status reporting

This foundation enables you to build sophisticated infrastructure automation that can scale across multiple environments and use cases.