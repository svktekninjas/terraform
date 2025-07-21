# ROSA Load Balancer Optimization Role - Learning Module

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Understanding the Problem](#understanding-the-problem)
4. [Role Architecture](#role-architecture)
5. [Step-by-Step Role Creation](#step-by-step-role-creation)
6. [Task Files Deep Dive](#task-files-deep-dive)
7. [Environment Integration](#environment-integration)
8. [Testing and Validation](#testing-and-validation)
9. [Integration with Main Playbook](#integration-with-main-playbook)
10. [Advanced Features](#advanced-features)
11. [Troubleshooting](#troubleshooting)
12. [Best Practices](#best-practices)

---

## Overview

This learning module teaches you how to create a comprehensive Ansible role for optimizing ROSA (Red Hat OpenShift Service on AWS) cluster load balancers. The role consolidates multiple LoadBalancer services into a single Application Load Balancer (ALB) with path-based routing, reducing costs and improving management.

### What You'll Learn
- How to structure a complex Ansible role
- Working with Kubernetes resources via Ansible
- AWS Load Balancer Controller integration
- Environment-specific configuration management
- Cost optimization techniques
- SSL/TLS certificate automation
- Load balancer testing and validation

### Business Problem Solved
- **Cost Reduction**: 67% savings on load balancer costs
- **Management Simplification**: Single endpoint for all monitoring services
- **Security Enhancement**: Centralized SSL/TLS management
- **Operational Efficiency**: Automated provisioning and cleanup

---

## Prerequisites

### Knowledge Requirements
- Basic Ansible concepts (playbooks, roles, tasks)
- Kubernetes/OpenShift fundamentals
- AWS Load Balancer concepts
- YAML syntax
- Basic shell scripting

### Tools and Access
- Ansible 2.12+ with kubernetes.core and amazon.aws collections
- kubectl/oc CLI tools
- AWS CLI configured with appropriate permissions
- Access to a ROSA cluster
- Text editor or IDE

### Required Permissions
- OpenShift cluster-admin or sufficient RBAC permissions
- AWS permissions for ELB, Route53, ACM operations
- Ability to create/modify Kubernetes resources

---

## Understanding the Problem

### Current State (Before Optimization)
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Internet                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                ┌───────────────────┼───────────────────┐
                │                   │                   │
                ▼                   ▼                   ▼
┌─────────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
│    Grafana ELB          │ │  Prometheus ELB     │ │  Alertmanager ELB   │
│  (LoadBalancer Service) │ │  (LoadBalancer Svc) │ │  (LoadBalancer Svc) │
└─────────────────────────┘ └─────────────────────┘ └─────────────────────┘

Cost: 3 ELBs × $16/month = $48/month + data transfer costs
```

### Target State (After Optimization)
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Internet                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Single ALB with Path-Based Routing                       │
│              monitoring-dev.svktek.com                                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
│   /grafana/*        │ │   /prometheus/*     │ │ /alertmanager/*     │
│   (ClusterIP Svc)   │ │   (ClusterIP Svc)   │ │ (ClusterIP Svc)     │
└─────────────────────┘ └─────────────────────┘ └─────────────────────┘

Cost: 1 ALB × $16/month = $16/month + data transfer costs
Savings: $32/month (67% reduction)
```

---

## Role Architecture

### Directory Structure
```
ansible/roles/rosa_loadbalancer/
├── defaults/
│   └── main.yml                    # Default variables
├── handlers/
├── meta/
│   └── main.yml                    # Role metadata and dependencies
├── tasks/
│   ├── main.yml                    # Main task orchestration
│   ├── consolidate_endpoints.yml   # Task 1: Inventory existing endpoints
│   ├── install_alb_controller.yml  # Task 2: Install AWS LB Controller
│   ├── create_alb_ingress.yml      # Task 3: Create ALB Ingress
│   ├── convert_services.yml        # Task 4: Convert to ClusterIP
│   ├── test_endpoints.yml          # Task 5: Test and validate
│   ├── dns_ssl_setup.yml           # Task 6: DNS/SSL configuration
│   └── cleanup_old_elbs.yml        # Task 7: Cleanup and validation
├── templates/
└── vars/
```

### Task Flow
1. **Consolidate Endpoints** → Inventory existing LoadBalancer services
2. **Install ALB Controller** → Ensure AWS Load Balancer Controller is ready
3. **Create ALB Ingress** → Configure path-based routing
4. **Convert Services** → Change LoadBalancer services to ClusterIP
5. **Test Endpoints** → Validate all services are accessible
6. **DNS/SSL Setup** → Configure domain and certificates
7. **Cleanup Old ELBs** → Remove unused resources and validate

---

## Step-by-Step Role Creation

### Step 1: Create the Role Directory Structure

```bash
# Navigate to your ansible roles directory
cd /path/to/your/ansible/roles

# Create the role directory structure
mkdir -p rosa_loadbalancer/{defaults,handlers,meta,tasks,templates,vars}

# Verify the structure
tree rosa_loadbalancer/
```

**Expected Output:**
```
rosa_loadbalancer/
├── defaults/
├── handlers/
├── meta/
├── tasks/
├── templates/
└── vars/
```

### Step 2: Create Role Metadata

Create `meta/main.yml`:
```yaml
---
galaxy_info:
  author: SRE Team
  description: ROSA Load Balancer Optimization Role
  company: SVKTek
  license: MIT
  
  min_ansible_version: 2.12
  
  platforms:
    - name: EL
      versions:
        - 8
        - 9
    - name: Ubuntu
      versions:
        - 20.04
        - 22.04
  
  galaxy_tags:
    - rosa
    - openshift
    - aws
    - loadbalancer
    - alb
    - kubernetes
    - monitoring
    - infrastructure
    - optimization
    - cost-saving

dependencies:
  - name: kubernetes.core
    version: ">=2.4.0"
  - name: amazon.aws
    version: ">=6.0.0"
```

**Key Learning Points:**
- **galaxy_info**: Metadata for Ansible Galaxy (if publishing)
- **dependencies**: Required Ansible collections
- **platforms**: Supported operating systems
- **min_ansible_version**: Minimum Ansible version requirement

### Step 3: Create Default Variables

Create `defaults/main.yml`:
```yaml
---
# ROSA Load Balancer Role Default Variables
# These variables work with environment-specific configurations

# ALB Controller Configuration
alb_controller_version: "v2.7.2"
iam_policy_name: "AWSLoadBalancerControllerIAMPolicy"
controller_service_account: "aws-load-balancer-controller"

# Target namespaces for load balancer optimization
target_namespaces:
  - "monitoring"
  - "openshift-monitoring"
  - "openshift-user-workload-monitoring"

# Service endpoint paths
service_path_mapping:
  grafana: "/grafana"
  prometheus: "/prometheus"
  alertmanager: "/alertmanager"

# Health Check Configuration
healthcheck_path: "/"
healthcheck_interval: 30
healthcheck_timeout: 5
healthy_threshold: 2
unhealthy_threshold: 5

# Validation and Testing
endpoint_test_timeout: 60
endpoint_test_retries: 3
validate_ssl_certificates: true

# Cleanup Configuration
cleanup_old_elbs: true
cleanup_timeout: 300
```

**Key Learning Points:**
- **Defaults vs Environment Variables**: Defaults are overridden by environment-specific configs
- **Naming Convention**: Use descriptive, hierarchical variable names
- **Documentation**: Comments explain each variable's purpose
- **Flexibility**: Variables allow customization without code changes

### Step 4: Create Environment-Specific Configuration

Create environment-specific configuration files:

**For Development (`environments/dev/loadbalancer-config.yml`):**
```yaml
---
# Development Environment Load Balancer Configuration
environment_name: "dev"
environment_suffix: "dev"

# ALB Configuration
alb_configuration:
  base_domain: "svktek-dev.example.com"
  alb_domain_name: "svktek-dev.rosa.example.com"
  alb_load_balancer_name: "monitoring-alb-dev"
  alb_scheme: "internet-facing"
  alb_target_type: "instance"
  alb_group_name: "monitoring-dev"

# SSL/TLS Configuration
ssl_configuration:
  ssl_redirect_enabled: true
  ssl_redirect_port: 443
  certificate_arn: ""
  validate_ssl_certificates: false  # Dev environment

# Target Namespaces
target_namespaces:
  - "monitoring"

# ALB Tags
alb_tags:
  Environment: "dev"
  Project: "ROSA"
  Owner: "SRE-Team"
  Purpose: "Monitoring"
```

**Repeat for Test and Production environments with appropriate values.**

**Key Learning Points:**
- **Environment Separation**: Different configs for dev/test/prod
- **Hierarchical Structure**: Nested variables for better organization
- **Environment-Specific Settings**: Dev allows more flexibility, prod is stricter
- **Tagging Strategy**: Consistent tagging for cost tracking and management

---

## Task Files Deep Dive

### Task 1: Consolidate Endpoints (`consolidate_endpoints.yml`)

**Purpose**: Inventory existing LoadBalancer services and routes to understand current state.

**Create the file:**
```yaml
---
- name: "Get all services with LoadBalancer type across target namespaces"
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Service
    namespace: "{{ item }}"
    field_selectors:
      - spec.type=LoadBalancer
  register: loadbalancer_services
  loop: "{{ target_namespaces }}"
  tags: [loadbalancer, consolidate, endpoints]

- name: "Consolidate LoadBalancer services information"
  set_fact:
    current_loadbalancer_services: "{{ current_loadbalancer_services | default([]) + item.resources }}"
  loop: "{{ loadbalancer_services.results }}"
  when: item.resources | length > 0
  tags: [loadbalancer, consolidate, endpoints]

- name: "Display current LoadBalancer services"
  debug:
    msg: |
      Found {{ current_loadbalancer_services | default([]) | length }} LoadBalancer services:
      {% for service in current_loadbalancer_services | default([]) %}
      - {{ service.metadata.namespace }}/{{ service.metadata.name }} -> {{ service.status.loadBalancer.ingress[0].hostname | default('pending') }}
      {% endfor %}
  tags: [loadbalancer, consolidate, endpoints]

- name: "Create endpoint mapping for ALB Ingress"
  set_fact:
    service_endpoints: "{{ service_endpoints | default([]) + [endpoint_item] }}"
  vars:
    endpoint_item:
      name: "{{ item.metadata.name }}"
      namespace: "{{ item.metadata.namespace }}"
      port: "{{ item.spec.ports[0].port }}"
      path: "/{{ item.metadata.name }}"
      current_hostname: "{{ item.status.loadBalancer.ingress[0].hostname | default('pending') }}"
  loop: "{{ current_loadbalancer_services | default([]) }}"
  tags: [loadbalancer, consolidate, endpoints]
```

**Key Learning Points:**
- **k8s_info module**: Queries Kubernetes API for resources
- **field_selectors**: Filters resources by specific fields
- **register**: Stores task output in variables
- **loop**: Iterates over lists (target_namespaces)
- **set_fact**: Creates/updates variables during playbook execution
- **conditional logic**: `when` clause for conditional task execution
- **Jinja2 templates**: Used in debug messages for formatting

### Task 2: Install ALB Controller (`install_alb_controller.yml`)

**Purpose**: Ensure AWS Load Balancer Controller is installed and ready.

**Create the file:**
```yaml
---
- name: "Check if AWS Load Balancer Controller deployment exists"
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    name: aws-load-balancer-controller
    namespace: aws-load-balancer-controller
  register: alb_deployment
  tags: [loadbalancer, alb-controller, install]

- name: "Get VPC ID from ROSA cluster"
  shell: |
    rosa describe cluster {{ cluster_name_prefix }}-{{ environment_name }} --output json | jq -r '.aws.subnet_ids[0]' | xargs aws ec2 describe-subnets --subnet-ids --query 'Subnets[0].VpcId' --output text
  register: vpc_id_result
  delegate_to: localhost
  when: vpc_id is not defined and alb_deployment.resources | length == 0
  tags: [loadbalancer, alb-controller, install]

- name: "Get AWS account ID"
  shell: aws sts get-caller-identity --query Account --output text
  delegate_to: localhost
  register: aws_account_id_result
  when: alb_deployment.resources | length == 0
  tags: [loadbalancer, alb-controller, install]

- name: "Install AWS Load Balancer Controller via Helm"
  kubernetes.core.helm:
    name: aws-load-balancer-controller
    chart_ref: eks/aws-load-balancer-controller
    release_namespace: aws-load-balancer-controller
    values:
      clusterName: "{{ cluster_name_prefix }}-{{ environment_name }}"
      serviceAccount:
        create: false
        name: "{{ controller_service_account }}"
      region: "{{ aws_region }}"
      vpcId: "{{ vpc_id }}"
  when: alb_deployment.resources | length == 0
  tags: [loadbalancer, alb-controller, install]

- name: "Wait for AWS Load Balancer Controller deployment to be ready"
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    name: aws-load-balancer-controller
    namespace: aws-load-balancer-controller
    wait: true
    wait_condition:
      type: Available
      status: "True"
    wait_timeout: 300
  tags: [loadbalancer, alb-controller, install]
```

**Key Learning Points:**
- **shell module**: Executes shell commands (rosa, aws cli)
- **delegate_to**: Runs tasks on specific hosts (localhost for AWS CLI)
- **helm module**: Manages Helm charts
- **wait conditions**: Waits for Kubernetes resources to be ready
- **conditional installation**: Only installs if not already present
- **Dynamic variable discovery**: Auto-detects VPC ID and AWS account

### Task 3: Create ALB Ingress (`create_alb_ingress.yml`)

**Purpose**: Create Kubernetes Ingress with ALB annotations for path-based routing.

**Create the file:**
```yaml
---
- name: "Create ALB Ingress with path-based routing"
  kubernetes.core.k8s:
    definition:
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: "{{ alb_configuration.alb_load_balancer_name }}-ingress"
        namespace: "{{ item }}"
        annotations:
          kubernetes.io/ingress.class: alb
          alb.ingress.kubernetes.io/scheme: "{{ alb_configuration.alb_scheme }}"
          alb.ingress.kubernetes.io/target-type: "{{ alb_configuration.alb_target_type }}"
          alb.ingress.kubernetes.io/group.name: "{{ alb_configuration.alb_group_name }}"
          alb.ingress.kubernetes.io/load-balancer-name: "{{ alb_configuration.alb_load_balancer_name }}"
          alb.ingress.kubernetes.io/ssl-redirect: "{{ ssl_configuration.ssl_redirect_port }}"
          alb.ingress.kubernetes.io/certificate-arn: "{{ ssl_configuration.certificate_arn }}"
          alb.ingress.kubernetes.io/tags: "{{ alb_tags | to_json }}"
      spec:
        rules:
        - host: "{{ alb_configuration.alb_domain_name }}"
          http:
            paths:
            - path: "{{ service_path_mapping.grafana }}"
              pathType: Prefix
              backend:
                service:
                  name: grafana
                  port:
                    number: 3000
            - path: "{{ service_path_mapping.prometheus }}"
              pathType: Prefix
              backend:
                service:
                  name: prometheus
                  port:
                    number: 9090
    state: present
  loop: "{{ target_namespaces }}"
  when: item == "monitoring"
  tags: [loadbalancer, alb-ingress, routing]
```

**Key Learning Points:**
- **k8s module**: Creates/updates Kubernetes resources
- **Ingress annotations**: ALB-specific configuration
- **Path-based routing**: Different paths route to different services
- **Resource definition**: Full Kubernetes manifest in YAML
- **Dynamic values**: Variables populate configuration fields
- **Namespace filtering**: Only create ingress in monitoring namespace

### Task 4: Convert Services (`convert_services.yml`)

**Purpose**: Convert LoadBalancer services to ClusterIP type.

**Create the file:**
```yaml
---
- name: "Get all services in target namespaces"
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Service
    namespace: "{{ item }}"
  register: all_services
  loop: "{{ target_namespaces }}"
  tags: [loadbalancer, services, clusterip]

- name: "Identify LoadBalancer type services"
  set_fact:
    loadbalancer_services: "{{ loadbalancer_services | default([]) + item.resources | selectattr('spec.type', 'equalto', 'LoadBalancer') | list }}"
  loop: "{{ all_services.results }}"
  tags: [loadbalancer, services, clusterip]

- name: "Backup current LoadBalancer service configurations"
  copy:
    content: "{{ item | to_nice_yaml }}"
    dest: "/tmp/backup_{{ item.metadata.name }}_{{ item.metadata.namespace }}_{{ ansible_date_time.epoch }}.yml"
  delegate_to: localhost
  loop: "{{ loadbalancer_services | default([]) }}"
  when: cleanup_configuration.backup_old_configurations
  tags: [loadbalancer, services, clusterip]

- name: "Convert LoadBalancer services to ClusterIP"
  kubernetes.core.k8s:
    definition:
      apiVersion: v1
      kind: Service
      metadata:
        name: "{{ item.metadata.name }}"
        namespace: "{{ item.metadata.namespace }}"
        labels: "{{ item.metadata.labels | default({}) }}"
        annotations: "{{ item.metadata.annotations | default({}) }}"
      spec:
        type: ClusterIP
        clusterIP: "{{ item.spec.clusterIP }}"
        ports: "{{ item.spec.ports }}"
        selector: "{{ item.spec.selector }}"
        sessionAffinity: "{{ item.spec.sessionAffinity | default('None') }}"
    state: present
  loop: "{{ loadbalancer_services | default([]) }}"
  when: 
    - item.spec.clusterIP != 'None' 
    - item.spec.clusterIP != ''
  tags: [loadbalancer, services, clusterip]
```

**Key Learning Points:**
- **selectattr filter**: Filters lists based on attribute values
- **Backup strategy**: Save original configurations before changes
- **Service conversion**: Change service type while preserving configuration
- **Safety checks**: Verify ClusterIP exists before conversion
- **Preserve metadata**: Keep labels, annotations, and selectors

### Task 5: Test Endpoints (`test_endpoints.yml`)

**Purpose**: Validate all services are accessible through the new ALB.

**Create the file:**
```yaml
---
- name: "Get ALB Ingress status"
  kubernetes.core.k8s_info:
    api_version: networking.k8s.io/v1
    kind: Ingress
    name: "{{ alb_configuration.alb_load_balancer_name }}-ingress"
    namespace: "monitoring"
  register: alb_ingress_info
  tags: [loadbalancer, test, validation]

- name: "Extract ALB hostname"
  set_fact:
    alb_hostname: "{{ alb_ingress_info.resources[0].status.loadBalancer.ingress[0].hostname }}"
  when: 
    - alb_ingress_info.resources | length > 0
    - alb_ingress_info.resources[0].status.loadBalancer.ingress | length > 0
  tags: [loadbalancer, test, validation]

- name: "Test Grafana endpoint"
  uri:
    url: "http://{{ alb_hostname }}{{ service_path_mapping.grafana }}"
    method: GET
    status_code: [200, 301, 302]
    timeout: "{{ validation_configuration.endpoint_test_timeout }}"
  register: grafana_test
  retries: "{{ validation_configuration.endpoint_test_retries }}"
  delay: 10
  when: alb_hostname is defined
  ignore_errors: "{{ not validation_configuration.fail_on_validation_error }}"
  tags: [loadbalancer, test, validation]

- name: "Display endpoint test results"
  debug:
    msg: |
      Endpoint Test Results:
      - ALB Hostname: {{ alb_hostname | default('Not Available') }}
      - Grafana Test: {{ 'PASS' if grafana_test.status == 200 else 'FAIL' }}
      - Prometheus Test: {{ 'PASS' if prometheus_test.status == 200 else 'FAIL' }}
  tags: [loadbalancer, test, validation]
```

**Key Learning Points:**
- **uri module**: Tests HTTP endpoints
- **Status code handling**: Accept multiple success codes
- **Retry logic**: Automatic retries with delays
- **Error handling**: ignore_errors for non-critical failures
- **Dynamic URLs**: Construct URLs from variables
- **Conditional execution**: Only run tests when hostname is available

### Task 6: DNS/SSL Setup (`dns_ssl_setup.yml`)

**Purpose**: Configure DNS records and SSL certificates for the ALB.

**Create the file:**
```yaml
---
- name: "Get current ALB hostname"
  kubernetes.core.k8s_info:
    api_version: networking.k8s.io/v1
    kind: Ingress
    name: "{{ alb_configuration.alb_load_balancer_name }}-ingress"
    namespace: "monitoring"
  register: current_alb_ingress
  tags: [loadbalancer, dns, ssl, security]

- name: "Create Route53 hosted zone if it doesn't exist"
  route53_zone:
    zone: "{{ alb_configuration.base_domain }}"
    state: present
  register: hosted_zone
  delegate_to: localhost
  when: current_alb_hostname is defined
  tags: [loadbalancer, dns, ssl, security]

- name: "Create DNS CNAME record for ALB"
  route53:
    state: present
    zone: "{{ alb_configuration.base_domain }}"
    record: "{{ alb_configuration.alb_domain_name }}"
    type: CNAME
    value: "{{ current_alb_hostname }}"
    ttl: 300
    overwrite: true
  delegate_to: localhost
  when: current_alb_hostname is defined
  tags: [loadbalancer, dns, ssl, security]

- name: "Request ACM certificate if not exists"
  shell: |
    aws acm request-certificate \
      --domain-name {{ alb_configuration.alb_domain_name }} \
      --validation-method DNS \
      --region {{ aws_region }} \
      --query 'CertificateArn' \
      --output text
  register: new_certificate
  delegate_to: localhost
  when: ssl_configuration.certificate_arn == ""
  tags: [loadbalancer, dns, ssl, security]
```

**Key Learning Points:**
- **route53_zone module**: Manages DNS zones
- **route53 module**: Manages DNS records
- **ACM integration**: Request and validate SSL certificates
- **DNS validation**: Automatic certificate validation via DNS
- **Conditional SSL**: Only configure SSL when certificates are available

### Task 7: Cleanup and Validation (`cleanup_old_elbs.yml`)

**Purpose**: Remove old ELBs and validate the final setup.

**Create the file:**
```yaml
---
- name: "Test final ALB endpoint"
  uri:
    url: "https://{{ alb_configuration.alb_domain_name }}{{ service_path_mapping.grafana }}"
    method: GET
    status_code: [200, 301, 302]
    timeout: 30
    validate_certs: "{{ ssl_configuration.validate_ssl_certificates }}"
  register: final_alb_test
  retries: 3
  delay: 10
  ignore_errors: true
  tags: [loadbalancer, cleanup, validation]

- name: "Get old ELB ARNs for cleanup"
  shell: |
    aws elbv2 describe-load-balancers --region {{ aws_region }} --query 'LoadBalancers[?contains(LoadBalancerName, `{{ cluster_name_prefix }}-{{ environment_name }}`) && !contains(LoadBalancerName, `{{ alb_configuration.alb_load_balancer_name }}`)].[LoadBalancerArn]' --output text
  register: old_elb_arns
  delegate_to: localhost
  when: cleanup_configuration.cleanup_old_elbs
  tags: [loadbalancer, cleanup, validation]

- name: "Delete old ELBs"
  shell: |
    aws elbv2 delete-load-balancer --load-balancer-arn {{ item }} --region {{ aws_region }}
  loop: "{{ old_elb_arns.stdout_lines }}"
  delegate_to: localhost
  when: 
    - cleanup_configuration.cleanup_old_elbs
    - old_elb_arns.stdout_lines | length > 0
    - final_alb_test.status == 200
  tags: [loadbalancer, cleanup, validation]

- name: "Display final optimization results"
  debug:
    msg: |
      
      ================================================================================
      ROSA Load Balancer Optimization Complete
      ================================================================================
      
      Environment: {{ environment_name }}
      New ALB Domain: {{ alb_configuration.alb_domain_name }}
      Services Optimized: {{ converted_services_summary | default([]) | length }}
      Cost Savings: ${{ (old_elb_arns.stdout_lines | length if old_elb_arns is defined else 0) * 16 }}/month
      
      Access URLs:
      - Grafana: https://{{ alb_configuration.alb_domain_name }}{{ service_path_mapping.grafana }}
      - Prometheus: https://{{ alb_configuration.alb_domain_name }}{{ service_path_mapping.prometheus }}
      
      ================================================================================
  tags: [loadbalancer, cleanup, validation]
```

**Key Learning Points:**
- **Final validation**: Ensure everything works before cleanup
- **Safe cleanup**: Only delete old resources if new ones work
- **AWS CLI integration**: Use AWS CLI for resource management
- **Cost calculation**: Calculate and display savings
- **Professional output**: Formatted summary for operators

### Step 5: Create Main Task File (`main.yml`)

**Purpose**: Orchestrate all tasks in the correct order.

**Create the file:**
```yaml
---
- name: "ROSA Load Balancer Optimization Role"
  debug:
    msg: "Starting ROSA Load Balancer Optimization with {{ target_namespaces | length }} namespaces"

- name: "Consolidate existing endpoints in available namespaces"
  include_tasks: consolidate_endpoints.yml
  tags: [loadbalancer, consolidate, endpoints]

- name: "Validate/Install AWS Load Balancer Controller"
  include_tasks: install_alb_controller.yml
  tags: [loadbalancer, alb-controller, install]

- name: "Create ALB Ingress with path-based routing"
  include_tasks: create_alb_ingress.yml
  tags: [loadbalancer, alb-ingress, routing]

- name: "Identify services and convert to ClusterIP"
  include_tasks: convert_services.yml
  tags: [loadbalancer, services, clusterip]

- name: "Test and validate service endpoints"
  include_tasks: test_endpoints.yml
  tags: [loadbalancer, test, validation]

- name: "Update with DNS and SSL certificates"
  include_tasks: dns_ssl_setup.yml
  tags: [loadbalancer, dns, ssl, security]

- name: "Final validation and cleanup old ELBs"
  include_tasks: cleanup_old_elbs.yml
  tags: [loadbalancer, cleanup, validation]

- name: "Load Balancer optimization completed successfully"
  debug:
    msg: "All tasks completed. New ALB endpoint: {{ alb_configuration.alb_domain_name }}"
```

**Key Learning Points:**
- **include_tasks**: Imports tasks from other files
- **Task orchestration**: Logical order of operations
- **Consistent tagging**: All tasks have loadbalancer tag
- **Status reporting**: Debug messages for progress tracking
- **Modular design**: Each task file handles one responsibility

---

## Environment Integration

### Step 6: Create Environment-Specific Variables

The role integrates with existing environment structure:

```
ansible/environments/
├── dev/
│   ├── dev.yml                     # General environment variables
│   ├── cluster-config.yml          # Cluster-specific configuration
│   ├── monitoring-config.yml       # Monitoring stack configuration
│   └── loadbalancer-config.yml     # Load balancer configuration (NEW)
├── test/
│   └── loadbalancer-config.yml     # Test environment config
└── prod/
    └── loadbalancer-config.yml     # Production environment config
```

### Variable Precedence
1. **Role defaults** (`defaults/main.yml`) - Lowest priority
2. **Environment variables** (`environments/*/loadbalancer-config.yml`) - Highest priority
3. **Playbook variables** - Can override both

### Integration Example
```yaml
# In your playbook
vars_files:
  - "../environments/{{ environment }}/{{ environment }}.yml"
  - "../environments/{{ environment }}/cluster-config.yml"
  - "../environments/{{ environment }}/loadbalancer-config.yml"
```

**Key Learning Points:**
- **Separation of concerns**: Each file handles specific configuration
- **Environment isolation**: Dev/test/prod have different settings
- **Variable hierarchy**: Understand precedence rules
- **Flexible configuration**: Easy to modify without code changes

---

## Testing and Validation

### Step 7: Test the Role

#### Unit Testing (Individual Tasks)
```bash
# Test only endpoint consolidation
ansible-playbook -i inventory playbooks/main.yml --tags consolidate -e environment=dev

# Test only ALB controller installation
ansible-playbook -i inventory playbooks/main.yml --tags alb-controller -e environment=dev

# Test only endpoint validation
ansible-playbook -i inventory playbooks/main.yml --tags test -e environment=dev
```

#### Integration Testing (Full Role)
```bash
# Run complete load balancer optimization
ansible-playbook -i inventory playbooks/main.yml --tags loadbalancer -e environment=dev

# Dry run to see what would happen
ansible-playbook -i inventory playbooks/main.yml --tags loadbalancer -e environment=dev --check

# Verbose output for debugging
ansible-playbook -i inventory playbooks/main.yml --tags loadbalancer -e environment=dev -vvv
```

#### Validation Checklist
- [ ] ALB Controller is installed and running
- [ ] Ingress resources are created with correct annotations
- [ ] Services are converted to ClusterIP type
- [ ] All endpoints return HTTP 200/301/302
- [ ] SSL certificates are configured (if enabled)
- [ ] DNS records point to ALB
- [ ] Old ELBs are deleted
- [ ] Cost savings are calculated correctly

**Key Learning Points:**
- **Incremental testing**: Test each task individually
- **Tag-based execution**: Run specific parts of the role
- **Dry run capabilities**: Preview changes before execution
- **Comprehensive validation**: Check all components work together

---

## Integration with Main Playbook

### Step 8: Update the Master Playbook

**Current main playbook structure:**
```yaml
# ansible/playbooks/main.yml
- name: ROSA Infrastructure Setup
  hosts: localhost
  connection: local
  gather_facts: yes
  
  roles:
    - role: aws-setup
      tags: ['aws', 'setup']
    - role: rosa-cli
      tags: ['rosa', 'cli']
    - role: validation
      tags: ['validation', 'pre-checks']
    - role: cluster
      tags: ['cluster', 'rosa-cluster']
    - role: monitoring
      tags: ['monitoring', 'observability']
    # ADD HERE: Load balancer optimization
```

**Add the load balancer role:**
```yaml
    - role: rosa_loadbalancer
      tags: ['loadbalancer', 'optimization', 'alb']
```

### Execution Examples

#### Full Infrastructure Deployment
```bash
# Deploy complete ROSA infrastructure including load balancer optimization
ansible-playbook -i inventory playbooks/main.yml -e environment=dev
```

#### Selective Deployment
```bash
# Deploy only monitoring and load balancer optimization
ansible-playbook -i inventory playbooks/main.yml --tags monitoring,loadbalancer -e environment=dev

# Deploy everything except load balancer optimization
ansible-playbook -i inventory playbooks/main.yml --skip-tags loadbalancer -e environment=dev
```

#### Environment-Specific Deployment
```bash
# Production deployment with strict validation
ansible-playbook -i inventory playbooks/main.yml -e environment=prod

# Development deployment with relaxed validation
ansible-playbook -i inventory playbooks/main.yml -e environment=dev
```

**Key Learning Points:**
- **Role dependencies**: Load balancer depends on monitoring being deployed
- **Execution order**: Roles run in sequence as defined
- **Tag strategy**: Use consistent tagging for selective execution
- **Environment handling**: Same playbook works for all environments

---

## Advanced Features

### Error Handling and Recovery

#### Rollback Strategy
```yaml
- name: "Rollback to LoadBalancer services if ALB fails"
  kubernetes.core.k8s:
    definition:
      apiVersion: v1
      kind: Service
      metadata:
        name: "{{ item.metadata.name }}"
        namespace: "{{ item.metadata.namespace }}"
      spec:
        type: LoadBalancer
        ports: "{{ item.spec.ports }}"
        selector: "{{ item.spec.selector }}"
    state: present
  loop: "{{ loadbalancer_services | default([]) }}"
  when: 
    - final_alb_test.status != 200
    - rollback_on_failure | default(false)
  tags: [loadbalancer, rollback]
```

#### Health Checks
```yaml
- name: "Continuous health check during transition"
  uri:
    url: "http://{{ alb_hostname }}{{ item.path }}"
    method: GET
    status_code: [200, 301, 302]
  register: health_check
  until: health_check.status == 200
  retries: 10
  delay: 30
  loop:
    - { path: "{{ service_path_mapping.grafana }}" }
    - { path: "{{ service_path_mapping.prometheus }}" }
  tags: [loadbalancer, health-check]
```

### Monitoring and Alerting Integration

#### CloudWatch Metrics
```yaml
- name: "Create CloudWatch dashboard for ALB"
  shell: |
    aws cloudwatch put-dashboard \
      --dashboard-name "ROSA-LoadBalancer-{{ environment_name }}" \
      --dashboard-body file://templates/alb-dashboard.json
  delegate_to: localhost
  tags: [loadbalancer, monitoring]
```

#### Slack Notifications
```yaml
- name: "Send optimization completion notification"
  uri:
    url: "{{ slack_webhook_url }}"
    method: POST
    body: |
      {
        "text": "ROSA Load Balancer Optimization Completed",
        "attachments": [
          {
            "color": "good",
            "fields": [
              {
                "title": "Environment",
                "value": "{{ environment_name }}",
                "short": true
              },
              {
                "title": "Cost Savings",
                "value": "${{ cost_savings }}/month",
                "short": true
              }
            ]
          }
        ]
      }
    body_format: json
  when: slack_webhook_url is defined
  tags: [loadbalancer, notification]
```

### Security Enhancements

#### WAF Integration
```yaml
- name: "Associate WAF with ALB"
  shell: |
    aws wafv2 associate-web-acl \
      --web-acl-arn {{ waf_acl_arn }} \
      --resource-arn {{ alb_arn }} \
      --region {{ aws_region }}
  delegate_to: localhost
  when: waf_acl_arn is defined
  tags: [loadbalancer, security, waf]
```

#### Security Groups
```yaml
- name: "Update ALB security group rules"
  ec2_group:
    name: "{{ alb_security_group_name }}"
    description: "Security group for ROSA monitoring ALB"
    vpc_id: "{{ vpc_id }}"
    rules:
      - proto: tcp
        ports:
          - 80
          - 443
        cidr_ip: "{{ allowed_cidr | default('0.0.0.0/0') }}"
        rule_desc: "Allow HTTP/HTTPS traffic"
    tags:
      Environment: "{{ environment_name }}"
      Purpose: "ROSA-LoadBalancer"
  delegate_to: localhost
  tags: [loadbalancer, security]
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: ALB Controller Not Installing
**Symptoms:**
- Helm deployment fails
- Controller pods not starting
- RBAC permission errors

**Debugging:**
```bash
# Check controller deployment
oc get deployment -n aws-load-balancer-controller

# Check pod logs
oc logs -n aws-load-balancer-controller deployment/aws-load-balancer-controller

# Check RBAC
oc get clusterrole aws-load-balancer-controller
oc get clusterrolebinding aws-load-balancer-controller
```

**Solution:**
```yaml
# Ensure proper IAM roles and policies
- name: "Verify IAM role for service account"
  shell: |
    aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole
  register: iam_role_check
  failed_when: iam_role_check.rc != 0
```

#### Issue 2: Ingress Not Creating ALB
**Symptoms:**
- Ingress exists but no ALB created
- ALB hostname not populated
- Services not accessible

**Debugging:**
```bash
# Check ingress annotations
oc describe ingress monitoring-alb-dev-ingress -n monitoring

# Check ALB controller logs
oc logs -n aws-load-balancer-controller deployment/aws-load-balancer-controller -f

# Check AWS Load Balancer status
aws elbv2 describe-load-balancers --region us-east-1
```

**Solution:**
```yaml
# Validate ingress class and annotations
- name: "Verify ingress class exists"
  kubernetes.core.k8s_info:
    api_version: networking.k8s.io/v1
    kind: IngressClass
    name: alb
  register: ingress_class_check
  failed_when: ingress_class_check.resources | length == 0
```

#### Issue 3: Services Not Accessible After Conversion
**Symptoms:**
- Services converted to ClusterIP
- Applications can't reach services
- Internal DNS resolution fails

**Debugging:**
```bash
# Check service endpoints
oc get endpoints -n monitoring

# Test internal connectivity
oc run test-pod --image=busybox --restart=Never -- nslookup grafana.monitoring.svc.cluster.local

# Check network policies
oc get networkpolicies -n monitoring
```

**Solution:**
```yaml
# Verify service selectors match pod labels
- name: "Validate service selectors"
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Service
    name: "{{ item.name }}"
    namespace: "{{ item.namespace }}"
  register: service_check
  failed_when: service_check.resources[0].spec.selector | length == 0
  loop: "{{ converted_services_summary }}"
```

#### Issue 4: SSL Certificate Validation Fails
**Symptoms:**
- Certificate stuck in pending validation
- HTTPS endpoints not accessible
- SSL redirect not working

**Debugging:**
```bash
# Check certificate status
aws acm describe-certificate --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/abc123

# Check DNS validation records
aws route53 list-resource-record-sets --hosted-zone-id Z123456789
```

**Solution:**
```yaml
# Manually create validation records
- name: "Create DNS validation record"
  route53:
    state: present
    zone: "{{ alb_configuration.base_domain }}"
    record: "{{ validation_record.Name }}"
    type: "{{ validation_record.Type }}"
    value: "{{ validation_record.Value }}"
    ttl: 60
  when: validation_record is defined
```

### Debug Mode

Enable debug mode in development:
```yaml
# In dev environment
dev_settings:
  debug_mode: true
  verbose_logging: true
  enable_debug_annotations: true
  skip_ssl_validation: true
```

This adds debug annotations and verbose logging to help troubleshoot issues.

---

## Best Practices

### 1. Code Organization
- **Modular design**: Each task file handles one responsibility
- **Consistent naming**: Use descriptive, hierarchical names
- **Proper tagging**: Apply consistent tags for selective execution
- **Documentation**: Comment complex logic and variables

### 2. Error Handling
- **Graceful degradation**: Handle failures without breaking entire deployment
- **Rollback capabilities**: Provide mechanisms to revert changes
- **Comprehensive logging**: Log all significant actions and errors
- **Validation checks**: Verify prerequisites before making changes

### 3. Security
- **Least privilege**: Use minimal required permissions
- **Secret management**: Never hardcode sensitive information
- **SSL/TLS**: Always use encryption in production
- **Network security**: Implement proper security groups and network policies

### 4. Performance
- **Parallel execution**: Use async operations where possible
- **Resource efficiency**: Minimize API calls and resource usage
- **Caching**: Cache frequently accessed data
- **Timeouts**: Set appropriate timeouts for all operations

### 5. Maintenance
- **Version control**: Track all changes in Git
- **Testing**: Implement comprehensive testing strategies
- **Documentation**: Keep documentation up to date
- **Monitoring**: Implement monitoring and alerting

### 6. Environment Management
- **Configuration separation**: Keep environment configs separate
- **Secrets management**: Use proper secret management tools
- **Promotion process**: Implement proper dev → test → prod promotion
- **Backup strategy**: Backup configurations before changes

---

## Conclusion

This learning module has walked you through creating a comprehensive ROSA Load Balancer Optimization role from scratch. You've learned:

1. **Role Structure**: How to organize complex Ansible roles
2. **Kubernetes Integration**: Working with Kubernetes resources via Ansible
3. **AWS Integration**: Managing AWS resources from Ansible
4. **Environment Management**: Handling multiple environments effectively
5. **Error Handling**: Building robust, production-ready automation
6. **Testing**: Validating your automation works correctly
7. **Integration**: Connecting with existing infrastructure

### Next Steps
1. **Deploy the role** in your development environment
2. **Test thoroughly** before promoting to production
3. **Monitor performance** and cost savings
4. **Extend functionality** with additional features
5. **Share knowledge** with your team

### Additional Resources
- [Ansible Kubernetes Collection Documentation](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/)
- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [ROSA Documentation](https://docs.openshift.com/rosa/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

Remember: This role represents a significant cost optimization opportunity while improving operational efficiency. The modular design makes it easy to extend and maintain as your infrastructure evolves.