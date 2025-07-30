# Naming Server (Eureka) Deployment Guide
## Complete Step-by-Step Tutorial for Beginners

This comprehensive guide will walk you through creating a complete Ansible role for deploying Naming Server (Eureka Service Discovery) using Helm charts on OpenShift/Kubernetes. You'll learn how to create the entire directory structure and write all the code from scratch, exactly as implemented in our current system.

## Prerequisites

- Basic understanding of Ansible, Helm, and Kubernetes/OpenShift
- Understanding of Spring Cloud Netflix Eureka
- Access to an OpenShift/Kubernetes cluster
- Helm CLI installed (version 3.x)
- OpenShift CLI (oc) installed
- Ansible installed with kubernetes.core collection

## Overview

We'll create a complete deployment system including:
1. Ansible role structure for cf-deployment with Naming Server focus
2. Helm chart specifically for Naming Server (Eureka) service
3. Environment-specific configurations
4. Service discovery setup and configuration
5. Spring Boot Admin integration
6. Port configuration (8761) and environment variables
7. Deployment automation with monitoring capabilities

---

## Part 1: Understanding the Naming Server Architecture

### Naming Server Service Details
- **Service Name**: `naming-server-new`
- **Port**: `8761` (standard Eureka server port)
- **Purpose**: Service discovery and registration for microservices
- **Framework**: Spring Cloud Netflix Eureka Server
- **Container Image**: `naming-server-service:latest`

### Key Features We'll Implement
- **Eureka Server Configuration**: Service registry and discovery
- **Spring Boot Admin Integration**: Monitoring and management
- **Health Checks**: Kubernetes liveness/readiness probes
- **External Access**: OpenShift routes
- **Resource Management**: CPU/Memory limits
- **Environment Variables**: Dynamic configuration
- **Rolling Updates**: Zero-downtime deployments

### Service Dependencies
- **Dependent Services**: All microservices register with this server
- **Monitoring**: Spring Boot Admin for health monitoring
- **No Dependencies**: This is the foundational service discovery component

---

## Part 2: Creating the Ansible Role Foundation

### Step 1: Create the Base Role Directory Structure

```bash
# Navigate to your ansible project root
cd /path/to/your/ansible/project

# Create the complete cf-deployment role structure
mkdir -p roles/cf-deployment/{defaults,tasks,vars,templates,handlers,meta,Doc-deployment,execution}

# Create additional directories for documentation and execution guides
mkdir -p roles/cf-deployment/Doc-deployment
mkdir -p roles/cf-deployment/execution
```

### Step 2: Create Role Meta Information

Create `roles/cf-deployment/meta/main.yml`:

```yaml
---
galaxy_info:
  author: ConsultingFirm DevOps Team
  description: ConsultingFirm microservices deployment role with Naming Server (Eureka) support
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
        - 20.04
        - 22.04
  galaxy_tags:
    - deployment
    - microservices
    - naming-server
    - eureka
    - service-discovery
    - openshift
    - kubernetes
    - helm
    - spring-boot
    - spring-cloud

dependencies:
  - name: kubernetes.core
    version: ">=2.3.0"
```

### Step 3: Create Default Variables for Naming Server

Create `roles/cf-deployment/defaults/main.yml`:

```yaml
---
# Default variables for CF Deployment Role with Naming Server focus

# Default environment configuration (can be overridden by environment configs)
env: dev
cf_environment: "{{ env | default('dev') }}"
cf_namespace: "cf-{{ env | default('dev') }}"
cf_release_name: "cf-microservices-{{ env | default('dev') }}"

# Helm chart configuration
helm_chart_path: "{{ playbook_dir }}/../helm-charts/cf-microservices"
values_file: "{{ playbook_dir }}/../environments/{{ cf_environment }}/deployment-values.yaml"

# Service deployment flags - Fine-grained control
deploy_naming_server_only: false
deploy_api_gateway_only: false
deploy_spring_boot_admin_only: false
deploy_config_service_only: false
deploy_business_services_only: false
deploy_frontend_only: false

# Individual business service deployment flags
deploy_excel_service_only: false
deploy_bench_profile_only: false
deploy_daily_submissions_only: false
deploy_interviews_only: false
deploy_placements_only: false

# Naming Server specific configuration
naming_server_config:
  enabled: true
  replicas: 1
  port: 8761
  targetPort: 8761
  image:
    repository: "naming-server-service"
    tag: "latest"
    pullPolicy: "Always"
  resources:
    limits:
      cpu: "500m"
      memory: "512Mi"
    requests:
      cpu: "200m"
      memory: "256Mi"
  # Eureka Server specific environment variables
  environment_variables:
    - name: "SPRING_PROFILES_ACTIVE"
      value: "openshift"
    - name: "SERVER_PORT"
      value: "8761"
    - name: "EUREKA_CLIENT_REGISTER_WITH_EUREKA"
      value: "false"
    - name: "EUREKA_CLIENT_FETCH_REGISTRY"
      value: "false"
    - name: "EUREKA_SERVER_ENABLE_SELF_PRESERVATION"
      value: "false"
    - name: "EUREKA_SERVER_EVICTION_INTERVAL_TIMER_IN_MS"
      value: "15000"
    - name: "EUREKA_INSTANCE_HOSTNAME"
      value: "naming-server-new"
    - name: "SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL"
      value: "http://naming-server-new:8761"
    - name: "SPRING_BOOT_ADMIN_CLIENT_URL"
      value: "http://spring-boot-admin:8082"
    - name: "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE"
      value: "health,info,metrics,env,eureka"
    - name: "MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS"
      value: "always"

# Deployment timeouts (in seconds)
helm_timeout: 600
deployment_wait_timeout: 600

# Verification settings
verify_deployment: true
show_deployment_status: true

# Health check configuration for Naming Server
health_check_config:
  liveness_probe:
    path: "/actuator/health"
    initial_delay_seconds: 60
    period_seconds: 30
    timeout_seconds: 10
    failure_threshold: 3
  readiness_probe:
    path: "/actuator/health"
    initial_delay_seconds: 30
    period_seconds: 10
    timeout_seconds: 5
    failure_threshold: 3
  startup_probe:
    path: "/actuator/health"
    initial_delay_seconds: 20
    period_seconds: 10
    timeout_seconds: 5
    failure_threshold: 30

# Route configuration for external access
route_config:
  enabled: true
  tls:
    termination: "edge"
  annotations:
    haproxy.router.openshift.io/timeout: "60s"

# Eureka Server specific configuration
eureka_server_config:
  enable_self_preservation: false
  eviction_interval_timer_ms: 15000
  response_cache_update_interval_ms: 5000
  response_cache_auto_expiration_in_seconds: 180
  peer_eureka_nodes_update_interval_ms: 600000
  registry_sync_retries: 0
  registry_sync_retry_wait_ms: 30000
  max_threads_for_status_replication: 1
  max_threads_for_peer_replication: 1

# ECR Token Management Configuration (if using private registry)
ecr_token_config:
  deployment_name: "ecr-credentials-sync"
  service_account_name: "ecr-credentials-sync"
  rbac_role_name: "ecr-secret-manager"
  rbac_binding_name: "ecr-credentials-sync-binding"
  ecr_registry: "818140567777.dkr.ecr.us-east-1.amazonaws.com"
  aws_region: "us-east-1"
  iam_role_arn: "arn:aws:iam::606639739464:role/ROSAECRAssumeRole"
  secret_name: "ecr-secret"
  base_image: "amazon/aws-cli:latest"
  app_version: "1.0"
  timezone: "America/New_York"
  refresh_interval_hours: 6

# ECR token management control flags
deploy_ecr_token_management: false
ecr_token_management_enabled: "{{ deploy_ecr_token_management | default(false) }}"
```

### Step 4: Create Role Variables

Create `roles/cf-deployment/vars/main.yml`:

```yaml
---
# Internal variables for CF Deployment Role - Naming Server Focus

# Supported environments
supported_environments:
  - dev
  - test
  - prod

# Service port mappings - Naming Server focus
service_ports:
  naming_server: 8761  # Standard Eureka server port
  api_gateway: 8765
  spring_boot_admin: 8082
  config_service: 8888
  excel_service: 8080
  bench_profile: 8080
  daily_submissions: 8080
  interviews: 8080
  placements: 8080
  frontend: 80

# Naming Server specific variables
naming_server_vars:
  service_name: "naming-server-new"
  app_label: "naming-server-new"
  chart_name: "naming-server"
  default_replicas: 1
  min_replicas: 1
  max_replicas: 3

# ECR registry configuration
ecr_registry: 818140567777.dkr.ecr.us-east-1.amazonaws.com/consultingfirm

# Service images mapping
service_images:
  naming_server: "{{ ecr_registry }}/naming-server-service:latest"
  api_gateway: "{{ ecr_registry }}/api-gateway-service:latest"
  spring_boot_admin: "{{ ecr_registry }}/spring-boot-admin:latest"
  config_service: "{{ ecr_registry }}/spring_cloud_config:latest"
  excel_service: "{{ ecr_registry }}/common-excel-service:latest"
  bench_profile: "{{ ecr_registry }}/bench-profiles-service:latest"
  daily_submissions: "{{ ecr_registry }}/daily-submissions-service:latest"
  interviews: "{{ ecr_registry }}/interviews-service:latest"
  placements: "{{ ecr_registry }}/placements-service:latest"
  frontend: "{{ ecr_registry }}/frontend:latest"

# Environment-specific replica counts for Naming Server
replica_counts:
  dev:
    naming_server: 1
    api_gateway: 1
    spring_boot_admin: 1
    config_service: 1
    excel_service: 1
    bench_profile: 1
    daily_submissions: 1
    interviews: 1
    placements: 1
    frontend: 1
  test:
    naming_server: 1  # Single instance for test
    api_gateway: 2
    spring_boot_admin: 1
    config_service: 1
    excel_service: 2
    bench_profile: 2
    daily_submissions: 2
    interviews: 2
    placements: 2
    frontend: 2
  prod:
    naming_server: 2  # Multiple instances for HA in production
    api_gateway: 3
    spring_boot_admin: 2
    config_service: 2
    excel_service: 3
    bench_profile: 3
    daily_submissions: 3
    interviews: 3
    placements: 3
    frontend: 3

# Resource configurations for different environments
resource_profiles:
  dev:
    naming_server:
      limits:
        cpu: "500m"
        memory: "512Mi"
      requests:
        cpu: "200m"
        memory: "256Mi"
  test:
    naming_server:
      limits:
        cpu: "1"
        memory: "1Gi"
      requests:
        cpu: "500m"
        memory: "512Mi"
  prod:
    naming_server:
      limits:
        cpu: "2"
        memory: "2Gi"
      requests:
        cpu: "1"
        memory: "1Gi"

# Service dependencies for Naming Server
service_dependencies:
  required: []  # Naming server has no dependencies
  optional:
    - spring_boot_admin  # For monitoring
  dependents:  # Services that depend on naming server
    - api_gateway
    - config_service
    - excel_service
    - bench_profile
    - daily_submissions
    - interviews
    - placements

# Eureka server configuration parameters
eureka_configuration:
  server:
    enable_self_preservation: false
    eviction_interval_timer_ms: 15000
    response_cache_update_interval_ms: 5000
    response_cache_auto_expiration_in_seconds: 180
  instance:
    hostname: "naming-server-new"
    prefer_ip_address: false
    lease_renewal_interval_in_seconds: 30
    lease_expiration_duration_in_seconds: 90
  client:
    register_with_eureka: false
    fetch_registry: false
    healthcheck_enabled: true
```

---

## Part 3: Creating the Core Tasks

### Step 5: Create Main Task Orchestration

Create `roles/cf-deployment/tasks/main.yml`:

```yaml
---
# CF Deployment Role - Main Tasks with Naming Server Focus
# Deploy ConsultingFirm microservices using Helm charts

- name: CF Deployment - Start orchestration
  debug:
    msg:
      - "Starting CF Deployment orchestration"
      - "Environment: {{ cf_environment }}"
      - "Namespace: {{ cf_namespace }}"
      - "Release: {{ cf_release_name }}"
      - "Naming Server Configuration:"
      - "  Port: {{ naming_server_config.port }}"
      - "  Replicas: {{ naming_server_config.replicas }}"
      - "  Image: {{ naming_server_config.image.repository }}:{{ naming_server_config.image.tag }}"
      - "  Eureka Server: {{ eureka_server_config.enable_self_preservation }}"
  tags:
    - cf-deployment
    - deployment
    - microservices
    - orchestration
    - naming-server

- name: Validate environment and prerequisites
  include_tasks: validate_prerequisites.yml
  tags:
    - cf-deployment
    - validation
    - prerequisites

- name: Include CF Namespace Creation
  include_tasks: cf-namespace.yml
  tags:
    - cf-deployment
    - cf-namespace
    - deployment
    - microservices
    - namespace

- name: Include ECR Token Management
  include_tasks: ecr-token-management.yml
  when: ecr_token_management_enabled | bool
  tags:
    - cf-deployment
    - ecr-token-management
    - continuous-auth
    - deployment
    - microservices

- name: Include CF Microservices Deployment
  include_tasks: cf-microservices.yml
  tags:
    - cf-deployment
    - deployment
    - microservices
    - naming-server

- name: Include Naming Server Specific Validations
  include_tasks: naming-server-validations.yml
  when: 
    - naming_server_config.enabled | bool
    - verify_deployment | bool
  tags:
    - cf-deployment
    - naming-server
    - validation
    - verify

- name: CF Deployment - Orchestration completed
  debug:
    msg:
      - "CF Deployment orchestration completed successfully"
      - "Environment: {{ cf_environment }}"
      - "Namespace: {{ cf_namespace }}"
      - "Release: {{ cf_release_name }}"
      - "Naming Server Status: {{ 'Deployed' if naming_server_config.enabled else 'Skipped' }}"
      - "Eureka Server URL: http://naming-server-new:8761"
      - "Health Check: http://naming-server-new:8761/actuator/health"
  tags:
    - cf-deployment
    - complete
    - deployment
    - microservices
    - orchestration
```

### Step 6: Create Prerequisites Validation Task

Create `roles/cf-deployment/tasks/validate_prerequisites.yml`:

```yaml
---
# CF Deployment Role - Prerequisites Validation for Naming Server

- name: Validate environment parameter
  assert:
    that:
      - cf_environment in supported_environments
    fail_msg: "Invalid environment: {{ cf_environment }}. Must be one of: {{ supported_environments | join(', ') }}"
    success_msg: "Environment validation passed: {{ cf_environment }}"
  tags:
    - validation
    - prerequisites

- name: Check if Helm chart path exists
  stat:
    path: "{{ helm_chart_path }}"
  register: helm_chart_stat
  tags:
    - validation
    - prerequisites

- name: Validate Helm chart directory
  assert:
    that:
      - helm_chart_stat.stat.exists
      - helm_chart_stat.stat.isdir
    fail_msg: "Helm chart directory not found: {{ helm_chart_path }}"
    success_msg: "Helm chart directory found: {{ helm_chart_path }}"
  tags:
    - validation
    - prerequisites

- name: Check if values file exists
  stat:
    path: "{{ values_file }}"
  register: values_file_stat
  tags:
    - validation
    - prerequisites

- name: Validate values file
  assert:
    that:
      - values_file_stat.stat.exists
    fail_msg: "Values file not found: {{ values_file }}"
    success_msg: "Values file found: {{ values_file }}"
  tags:
    - validation     
    - prerequisites

- name: Validate Naming Server port configuration
  assert:
    that:
      - naming_server_config.port == 8761
      - naming_server_config.targetPort == 8761
    fail_msg: "Naming Server port must be 8761 (standard Eureka port)"
    success_msg: "Naming Server port configuration is correct"
  tags:
    - validation
    - prerequisites
    - naming-server

- name: Display Naming Server configuration summary
  debug:
    msg:
      - "=== Naming Server Configuration Summary ==="
      - "Service Name: {{ naming_server_vars.service_name }}"
      - "Port: {{ naming_server_config.port }}"
      - "Target Port: {{ naming_server_config.targetPort }}"
      - "Replicas: {{ naming_server_config.replicas }}"
      - "Image: {{ naming_server_config.image.repository }}:{{ naming_server_config.image.tag }}"
      - "Resources:"
      - "  CPU Limit: {{ naming_server_config.resources.limits.cpu }}"
      - "  Memory Limit: {{ naming_server_config.resources.limits.memory }}"
      - "  CPU Request: {{ naming_server_config.resources.requests.cpu }}"
      - "  Memory Request: {{ naming_server_config.resources.requests.memory }}"
      - "Eureka Configuration:"
      - "  Self Preservation: {{ eureka_server_config.enable_self_preservation }}"
      - "  Eviction Interval: {{ eureka_server_config.eviction_interval_timer_ms }}ms"
      - "Environment Variables: {{ naming_server_config.environment_variables | length }} configured"
      - "=============================================="
  tags:
    - validation
    - prerequisites
    - naming-server
```

### Step 7: Create Namespace Management Task

Create `roles/cf-deployment/tasks/cf-namespace.yml`:

```yaml
---
# CF Deployment Role - Namespace Management for Naming Server

- name: Set namespace based on environment
  set_fact:
    cf_namespace: "cf-{{ cf_environment }}"
  tags:
    - cf-deployment
    - cf-namespace
    - namespace

- name: Display namespace creation information
  debug:
    msg:
      - "Creating namespace for environment: {{ cf_environment }}"
      - "Namespace: {{ cf_namespace }}"
      - "Primary service: Naming Server (Eureka)"
      - "Service Discovery Port: 8761"
  tags:
    - cf-deployment
    - cf-namespace
    - namespace

- name: Create CF namespace
  kubernetes.core.k8s:
    name: "{{ cf_namespace }}"
    api_version: v1
    kind: Namespace
    state: present
    definition:
      metadata:
        name: "{{ cf_namespace }}"
        labels:
          name: "{{ cf_namespace }}"
          environment: "{{ cf_environment }}"
          managed-by: "ansible"
          app: "cf-microservices"
          component: "naming-server"
          service-discovery: "eureka"
        annotations:
          description: "ConsultingFirm microservices namespace for {{ cf_environment }} environment"
          "openshift.io/display-name": "CF Microservices - {{ cf_environment | title }}"
          "consul.hashicorp.com/connect-inject": "false"
          "eureka.server.url": "http://naming-server-new.{{ cf_namespace }}.svc.cluster.local:8761"
  tags:
    - cf-deployment
    - cf-namespace
    - namespace

- name: Verify CF namespace exists
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Namespace
    name: "{{ cf_namespace }}"
  register: namespace_verification  
  retries: 3
  delay: 5
  until: namespace_verification.resources | length > 0
  tags:
    - cf-deployment
    - cf-namespace
    - namespace
    - verify

- name: Display CF namespace status
  debug:
    msg:
      - "Namespace: {{ cf_namespace }}"
      - "Environment: {{ cf_environment }}"
      - "Status: {{ namespace_verification.resources[0].status.phase if namespace_verification.resources else 'Not Found' }}"
      - "Creation timestamp: {{ namespace_verification.resources[0].metadata.creationTimestamp if namespace_verification.resources else 'N/A' }}"
      - "Labels: {{ namespace_verification.resources[0].metadata.labels if namespace_verification.resources else {} }}"
      - "Eureka Server URL: http://naming-server-new.{{ cf_namespace }}.svc.cluster.local:8761"
  tags:
    - cf-deployment
    - cf-namespace  
    - namespace
    - verify

- name: Namespace creation completed
  debug:
    msg: "Namespace {{ cf_namespace }} is ready for Naming Server and microservices deployments"
  tags:
    - cf-deployment
    - cf-namespace
    - namespace
    - complete
```

---

## Part 4: Creating the Core Microservices Deployment

### Step 8: Create the Main Microservices Deployment Task

Create `roles/cf-deployment/tasks/cf-microservices.yml`:

```yaml
---
# CF Deployment Role - Helm Integration for Naming Server
# Deploy ConsultingFirm microservices using Helm charts with Naming Server focus

- name: Deploy CF Microservices using Helm (All Services)
  kubernetes.core.helm:
    name: "{{ cf_release_name | default('cf-microservices') }}"
    chart_ref: "{{ helm_chart_path }}"
    release_namespace: "{{ cf_namespace }}"
    create_namespace: false
    skip_crds: false
    values_files:
      - "{{ values_file }}"
    values:
      global:
        namespace: "{{ cf_namespace }}"
      # Override Naming Server configuration
      naming-server:
        service:
          port: "{{ naming_server_config.port }}"
          targetPort: "{{ naming_server_config.targetPort }}"
        deployment:
          replicas: "{{ naming_server_config.replicas }}"
          env: "{{ naming_server_config.environment_variables }}"
          resources: "{{ naming_server_config.resources }}"
        image:
          repository: "{{ naming_server_config.image.repository }}"
          tag: "{{ naming_server_config.image.tag }}"
          pullPolicy: "{{ naming_server_config.image.pullPolicy }}"
        route:
          enabled: "{{ route_config.enabled }}"
          tls:
            termination: "{{ route_config.tls.termination }}"
    state: present
    wait: true
    wait_timeout: "{{ helm_timeout }}s"
    force: true
  when: not (deploy_naming_server_only | default(false))
  tags:
    - cf-deployment
    - deployment
    - cf-deploy-all
    - helm-deploy

- name: Verify namespace creation
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Namespace
    name: "{{ cf_namespace }}"
  register: namespace_info
  tags:
    - cf-deployment
    - deployment
    - cf-namespace
    - verify

- name: Display namespace status
  debug:
    msg: "Namespace {{ cf_namespace }} status: {{ namespace_info.resources[0].status.phase if namespace_info.resources else 'Not Found' }}"
  tags:
    - cf-deployment
    - deployment
    - cf-namespace
    - verify

- name: Wait for all deployments to be ready
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    namespace: "{{ cf_namespace }}"
    label_selectors:
      - "app.kubernetes.io/instance={{ cf_release_name | default('cf-microservices') }}"
    wait: true
    wait_condition:
      type: Available
      status: "True"
    wait_timeout: "{{ deployment_wait_timeout }}"
  register: deployments_status
  when: verify_deployment | bool
  tags:
    - cf-deployment
    - deployment
    - cf-verify
    - verify

- name: Display deployment status
  debug:
    msg: "Found {{ deployments_status.resources | length }} deployments in {{ cf_namespace }} namespace"
  when: verify_deployment | bool and deployments_status is defined
  tags:
    - cf-deployment
    - deployment
    - cf-verify
    - verify

# Naming Server Only Deployment Task
- name: Deploy Naming Server only
  kubernetes.core.helm:
    name: "{{ cf_release_name | default('cf-microservices') }}"
    chart_ref: "{{ helm_chart_path }}"
    release_namespace: "{{ cf_namespace }}"
    create_namespace: false
    values_files:
      - "{{ values_file }}"
    values:
      global:
        namespace: "{{ cf_namespace }}"
      # Disable all other services
      namingServer:
        enabled: true
      apiGateway:
        enabled: false
      springBootAdmin:
        enabled: false
      configService:
        enabled: false
      excelService:
        enabled: false
      benchProfile:
        enabled: false
      dailySubmissions:
        enabled: false
      interviews:
        enabled: false
      placements:
        enabled: false
      frontend:
        enabled: false
      # Override Naming Server specific configuration
      naming-server:
        service:
          port: "{{ naming_server_config.port }}"
          targetPort: "{{ naming_server_config.targetPort }}"
        deployment:
          replicas: "{{ naming_server_config.replicas }}"
          env: "{{ naming_server_config.environment_variables }}"
          resources: "{{ naming_server_config.resources }}"
        image:
          repository: "{{ naming_server_config.image.repository }}"
          tag: "{{ naming_server_config.image.tag }}"
          pullPolicy: "{{ naming_server_config.image.pullPolicy }}"
        route:
          enabled: "{{ route_config.enabled }}"
          tls:
            termination: "{{ route_config.tls.termination }}"
    state: present
    wait: true
    wait_timeout: 300s
  when: deploy_naming_server_only | default(false)
  tags:
    - cf-deployment
    - deployment
    - cf-naming-server
    - naming-server

- name: Verify Naming Server deployment (when deployed individually)
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    name: "{{ naming_server_vars.service_name }}"
    namespace: "{{ cf_namespace }}"
    wait: true
    wait_condition:
      type: Available
      status: "True"
    wait_timeout: 300
  register: naming_server_deployment_status
  when: 
    - deploy_naming_server_only | default(false)
    - verify_deployment | bool
  tags:
    - cf-deployment
    - deployment
    - cf-naming-server
    - naming-server
    - verify

- name: Display Naming Server deployment status
  debug:
    msg:
      - "Naming Server Deployment Status:"
      - "  Name: {{ naming_server_vars.service_name }}"
      - "  Namespace: {{ cf_namespace }}"
      - "  Ready Replicas: {{ naming_server_deployment_status.resources[0].status.readyReplicas | default(0) }}"
      - "  Available Replicas: {{ naming_server_deployment_status.resources[0].status.availableReplicas | default(0) }}"
      - "  Desired Replicas: {{ naming_server_deployment_status.resources[0].status.replicas | default(0) }}"
      - "  Eureka Server Port: 8761"
      - "  Service Discovery URL: http://naming-server-new:8761/eureka/"
  when: 
    - deploy_naming_server_only | default(false)
    - verify_deployment | bool
    - naming_server_deployment_status is defined
  tags:
    - cf-deployment
    - deployment
    - cf-naming-server
    - naming-server
    - verify

- name: Wait for Naming Server to be healthy
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Pod
    namespace: "{{ cf_namespace }}"
    label_selectors:
      - "app={{ naming_server_vars.app_label }}"
    wait: true
    wait_condition:
      type: Ready
      status: "True"
    wait_timeout: 180
  register: naming_server_pods_status
  when: 
    - deploy_naming_server_only | default(false)
    - verify_deployment | bool
  tags:
    - cf-deployment
    - deployment
    - cf-naming-server
    - naming-server
    - verify

- name: Display Naming Server pod health status
  debug:
    msg:
      - "Naming Server Pods Health Status:"
      - "  Running Pods: {{ naming_server_pods_status.resources | selectattr('status.phase', 'equalto', 'Running') | list | length }}"
      - "  Ready Pods: {{ naming_server_pods_status.resources | selectattr('status.conditions', 'defined') | selectattr('status.conditions', 'selectattr', 'type', 'equalto', 'Ready') | selectattr('status.conditions', 'selectattr', 'status', 'equalto', 'True') | list | length }}"
      - "  Total Desired: {{ naming_server_config.replicas }}"
  when: 
    - deploy_naming_server_only | default(false)
    - verify_deployment | bool
    - naming_server_pods_status is defined
  tags:
    - cf-deployment
    - deployment
    - cf-naming-server
    - naming-server
    - verify
```

### Step 9: Create Naming Server Validation Task

Create `roles/cf-deployment/tasks/naming-server-validations.yml`:

```yaml
---
# CF Deployment Role - Naming Server Specific Validations

- name: Get Naming Server deployment status
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    name: "{{ naming_server_vars.service_name }}"
    namespace: "{{ cf_namespace }}"
  register: naming_server_deployment
  tags:
    - validation
    - naming-server
    - verify

- name: Get Naming Server service status
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Service
    name: "{{ naming_server_vars.service_name }}"
    namespace: "{{ cf_namespace }}"
  register: naming_server_service
  tags:
    - validation
    - naming-server
    - verify

- name: Get Naming Server route status
  kubernetes.core.k8s_info:
    api_version: route.openshift.io/v1
    kind: Route
    name: "{{ naming_server_vars.service_name }}"
    namespace: "{{ cf_namespace }}"
  register: naming_server_route
  ignore_errors: true
  tags:
    - validation
    - naming-server
    - verify

- name: Get Naming Server pods
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Pod
    namespace: "{{ cf_namespace }}"
    label_selectors:
      - "app={{ naming_server_vars.app_label }}"
  register: naming_server_pods
  tags:
    - validation
    - naming-server
    - verify

- name: Validate Naming Server deployment
  assert:
    that:
      - naming_server_deployment.resources | length > 0
      - naming_server_deployment.resources[0].status.readyReplicas | default(0) > 0
    fail_msg: "Naming Server deployment is not ready"
    success_msg: "Naming Server deployment is healthy"
  tags:
    - validation
    - naming-server
    - verify

- name: Validate Naming Server service port
  assert:
    that:
      - naming_server_service.resources | length > 0
      - naming_server_service.resources[0].spec.ports[0].port == 8761
    fail_msg: "Naming Server service is not properly configured on port 8761"
    success_msg: "Naming Server service is properly configured on port 8761"
  tags:
    - validation
    - naming-server
    - verify

- name: Check Naming Server environment variables
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    name: "{{ naming_server_vars.service_name }}"
    namespace: "{{ cf_namespace }}"
  register: naming_server_env_check
  tags:
    - validation
    - naming-server
    - verify

- name: Validate Eureka Server configuration
  assert:
    that:
      - naming_server_env_check.resources[0].spec.template.spec.containers[0].env is defined
      - naming_server_env_check.resources[0].spec.template.spec.containers[0].env | selectattr('name', 'equalto', 'SERVER_PORT') | selectattr('value', 'equalto', '8761') | list | length > 0
      - naming_server_env_check.resources[0].spec.template.spec.containers[0].env | selectattr('name', 'equalto', 'EUREKA_CLIENT_REGISTER_WITH_EUREKA') | selectattr('value', 'equalto', 'false') | list | length > 0
      - naming_server_env_check.resources[0].spec.template.spec.containers[0].env | selectattr('name', 'equalto', 'EUREKA_CLIENT_FETCH_REGISTRY') | selectattr('value', 'equalto', 'false') | list | length > 0
    fail_msg: "Naming Server environment variables are not properly configured for Eureka Server"
    success_msg: "Naming Server is properly configured as Eureka Server"
  tags:
    - validation
    - naming-server
    - verify

- name: Display Naming Server validation summary
  debug:
    msg:
      - "=== Naming Server Validation Summary ==="
      - "Deployment Status: {{ 'Ready' if naming_server_deployment.resources[0].status.readyReplicas | default(0) > 0 else 'Not Ready' }}"
      - "Ready Replicas: {{ naming_server_deployment.resources[0].status.readyReplicas | default(0) }}/{{ naming_server_deployment.resources[0].spec.replicas | default(0) }}"
      - "Service Port: {{ naming_server_service.resources[0].spec.ports[0].port if naming_server_service.resources else 'N/A' }}"
      - "Target Port: {{ naming_server_service.resources[0].spec.ports[0].targetPort if naming_server_service.resources else 'N/A' }}"
      - "Running Pods: {{ naming_server_pods.resources | selectattr('status.phase', 'equalto', 'Running') | list | length }}"
      - "External Route: {{ 'Available' if naming_server_route.resources else 'Not Available' }}"
      - "Route URL: {{ naming_server_route.resources[0].spec.host if naming_server_route.resources else 'N/A' }}"
      - "Eureka Server URL: http://naming-server-new:8761/eureka/"
      - "Health Check URL: http://naming-server-new:8761/actuator/health"
      - "Spring Boot Admin Integration: {{ 'Configured' if naming_server_env_check.resources[0].spec.template.spec.containers[0].env | selectattr('name', 'equalto', 'SPRING_BOOT_ADMIN_CLIENT_URL') | list | length > 0 else 'Not Configured' }}"
      - "=========================================="
  tags:
    - validation
    - naming-server  
    - verify

- name: Test Naming Server connectivity (if possible)
  uri:
    url: "http://{{ naming_server_vars.service_name }}.{{ cf_namespace }}.svc.cluster.local:8761/actuator/health"
    method: GET
    return_content: yes
    timeout: 10
  register: naming_server_health_check
  ignore_errors: true
  tags:
    - validation
    - naming-server
    - verify
    - connectivity

- name: Display connectivity test results
  debug:
    msg:
      - "Naming Server Health Check Results:"
      - "  Status: {{ 'Success' if naming_server_health_check.status == 200 else 'Failed' }}"
      - "  Response: {{ naming_server_health_check.content if naming_server_health_check.content is defined else 'No response' }}"
  when: naming_server_health_check is defined
  tags:
    - validation
    - naming-server
    - verify
    - connectivity

- name: Check Naming Server pod logs for errors (if pods are not ready)
  kubernetes.core.k8s_log:
    api_version: v1
    kind: Pod
    namespace: "{{ cf_namespace }}"
    name: "{{ item.metadata.name }}"
    tail_lines: 20
  register: pod_logs
  loop: "{{ naming_server_pods.resources }}"
  when: 
    - naming_server_pods.resources | length > 0
    - item.status.phase != 'Running' or (item.status.containerStatuses is defined and item.status.containerStatuses[0].ready == false)
  ignore_errors: true
  tags:
    - validation
    - naming-server
    - verify
    - troubleshoot

- name: Display problematic pod logs
  debug:
    msg:
      - "Pod {{ item.item.metadata.name }} logs:"
      - "{{ item.log }}"
  loop: "{{ pod_logs.results }}"
  when: 
    - pod_logs is defined
    - item.log is defined
  tags:
    - validation
    - naming-server
    - verify
    - troubleshoot
```

---

## Part 5: Creating the Helm Chart Structure

### Step 10: Create Main Helm Chart Directory Structure

```bash
# Navigate to your project root
cd /path/to/your/ansible/project

# Create the main helm chart structure
mkdir -p helm-charts/cf-microservices/{charts,templates}
mkdir -p helm-charts/cf-microservices/charts/naming-server/{templates,charts}

# Create templates directory for individual charts
mkdir -p helm-charts/cf-microservices/charts/naming-server/templates
```

### Step 11: Create Main Helm Chart Configuration

Create `helm-charts/cf-microservices/Chart.yaml`:

```yaml
apiVersion: v2
name: cf-microservices
description: ConsultingFirm Microservices Helm Chart with Naming Server (Eureka)
type: application
version: 1.0.0
appVersion: "1.0.0"
keywords:
  - microservices
  - spring-boot
  - naming-server
  - eureka
  - service-discovery
  - consulting-firm
  - spring-cloud
home: https://consultingfirm.com
sources:
  - https://github.com/consultingfirm/microservices
maintainers:
  - name: DevOps Team
    email: devops@consultingfirm.com
  - name: Naming Server Team
    email: naming-server@consultingfirm.com
dependencies:
  - name: naming-server
    version: "1.0.0"
    repository: "file://charts/naming-server"
    condition: namingServer.enabled
  - name: api-gateway
    version: "1.0.0"
    repository: "file://charts/api-gateway"
    condition: apiGateway.enabled
  - name: spring-boot-admin
    version: "1.0.0"
    repository: "file://charts/spring-boot-admin"
    condition: springBootAdmin.enabled
  - name: config-service
    version: "1.0.0"
    repository: "file://charts/config-service"
    condition: configService.enabled
```

### Step 12: Create Main Helm Values File with Naming Server Focus

Create `helm-charts/cf-microservices/values.yaml`:

```yaml
# Global configuration
global:
  namespace: cf-dev
  registry: 818140567777.dkr.ecr.us-east-1.amazonaws.com/consultingfirm
  pullPolicy: Always
  serviceAccount: ecr-sa
  
  dockerconfigjson: ""
  imagePullSecrets:
    - name: regcred 

# Service Account configuration
serviceAccount:
  create: false
  name: ecr-sa

# Service enablement flags
namingServer:
  enabled: true

apiGateway:
  enabled: true

springBootAdmin:
  enabled: true

configService:
  enabled: true

excelService:
  enabled: true

benchProfile:
  enabled: true

dailySubmissions:
  enabled: true

interviews:
  enabled: true

placements:
  enabled: true

frontend:
  enabled: true

# Individual service configurations
# Naming Server Configuration (Primary Service)
naming-server:
  image:
    repository: naming-server-service
    tag: latest
  service:
    port: 8761  # Standard Eureka server port
  deployment:
    replicas: 1
  route:
    enabled: true
    tls:
      termination: edge

api-gateway:
  image:
    repository: api-gateway-service
    tag: latest
  service:
    port: 8765
  deployment:
    replicas: 2
  route:
    enabled: true
    tls:
      termination: edge

spring-boot-admin:
  image:
    repository: spring-boot-admin
    tag: latest
  service:
    port: 8082
  deployment:
    replicas: 1
  route:
    enabled: true
    tls:
      termination: edge

config-service:
  image:
    repository: spring_cloud_config
    tag: latest
  service:
    port: 8888
  deployment:
    replicas: 1
  route:
    enabled: true
    tls:
      termination: edge

excel-service:
  image:
    repository: common-excel-service
    tag: latest
  service:
    port: 8080
  deployment:
    replicas: 2
  route:
    enabled: true
    tls:
      termination: edge

bench-profile:
  image:
    repository: bench-profiles-service
    tag: latest
  service:
    port: 8080
  deployment:
    replicas: 2
  route:
    enabled: true
    tls:
      termination: edge

daily-submissions:
  image:
    repository: daily-submissions-service
    tag: latest
  service:
    port: 8080
  deployment:
    replicas: 2
  route:
    enabled: true
    tls:
      termination: edge

interviews:
  image:
    repository: interviews-service
    tag: latest
  service:
    port: 8080
  deployment:
    replicas: 2
  route:
    enabled: true
    tls:
      termination: edge

placements:
  image:
    repository: placements-service
    tag: latest
  service:
    port: 8080
  deployment:
    replicas: 2
  route:
    enabled: true
    tls:
      termination: edge

frontend:
  image:
    repository: frontend
    tag: latest
  service:
    port: 80
  deployment:
    replicas: 2
  route:
    enabled: true
    tls:
      termination: edge
```

---

## Part 6: Creating Naming Server Specific Helm Chart

### Step 13: Create Naming Server Chart Configuration

Create `helm-charts/cf-microservices/charts/naming-server/Chart.yaml`:

```yaml
apiVersion: v2
name: naming-server
description: Naming Server (Eureka) Helm Chart for Service Discovery
type: application
version: 1.0.0
appVersion: "2.7.0"
keywords:
  - naming-server
  - eureka
  - service-discovery
  - spring-cloud-netflix
  - microservices
  - registry
home: https://spring.io/projects/spring-cloud-netflix
sources:
  - https://github.com/spring-cloud/spring-cloud-netflix
maintainers:
  - name: Naming Server Team
    email: naming-server@consultingfirm.com  
  - name: DevOps Team
    email: devops@consultingfirm.com
annotations:
  category: Microservices
  licenses: Apache-2.0
  service-discovery: eureka
  port: "8761"
```

### Step 14: Create Naming Server Values with Environment Variables

Create `helm-charts/cf-microservices/charts/naming-server/values.yaml`:

```yaml
image:
  repository: naming-server-service
  tag: latest
  pullPolicy: Always

service:
  type: ClusterIP
  port: 8761      # Standard Eureka server port
  targetPort: 8761

deployment:
  replicas: 1
  # Environment variables for Naming Server (Eureka Server) configuration
  env:
    - name: SPRING_PROFILES_ACTIVE
      value: "openshift"
    - name: SERVER_PORT
      value: "8761"
    # Eureka Server Configuration
    - name: EUREKA_CLIENT_REGISTER_WITH_EUREKA
      value: "false"
    - name: EUREKA_CLIENT_FETCH_REGISTRY
      value: "false"
    - name: EUREKA_SERVER_ENABLE_SELF_PRESERVATION
      value: "false"
    - name: EUREKA_SERVER_EVICTION_INTERVAL_TIMER_IN_MS
      value: "15000"
    - name: EUREKA_SERVER_RESPONSE_CACHE_UPDATE_INTERVAL_MS
      value: "5000"
    - name: EUREKA_SERVER_RESPONSE_CACHE_AUTO_EXPIRATION_IN_SECONDS
      value: "180"
    # Instance Configuration
    - name: EUREKA_INSTANCE_HOSTNAME
      value: "naming-server-new"
    - name: EUREKA_INSTANCE_PREFER_IP_ADDRESS
      value: "false"
    - name: EUREKA_INSTANCE_LEASE_RENEWAL_INTERVAL_IN_SECONDS
      value: "30"
    - name: EUREKA_INSTANCE_LEASE_EXPIRATION_DURATION_IN_SECONDS
      value: "90"
    # Spring Boot Admin Integration
    - name: SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL
      value: "http://naming-server-new:8761"
    - name: SPRING_BOOT_ADMIN_CLIENT_URL
      value: "http://spring-boot-admin:8082"
    # Management Endpoints
    - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
      value: "health,info,metrics,env,eureka"
    - name: MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS
      value: "always"
    - name: MANAGEMENT_SECURITY_ENABLED
      value: "false"
    # Logging Configuration
    - name: LOGGING_LEVEL_COM_NETFLIX_EUREKA
      value: "INFO"
    - name: LOGGING_LEVEL_COM_NETFLIX_DISCOVERY
      value: "INFO"
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 256Mi
  # Deployment strategy
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1

# Health check configuration - Critical for Eureka Server
healthCheck:
  livenessProbe:
    httpGet:
      path: /actuator/health
      port: 8761
    initialDelaySeconds: 60
    periodSeconds: 30
    timeoutSeconds: 10
    failureThreshold: 3
    successThreshold: 1
  readinessProbe:
    httpGet:
      path: /actuator/health
      port: 8761
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
    successThreshold: 1
  startupProbe:
    httpGet:
      path: /actuator/health
      port: 8761
    initialDelaySeconds: 20
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 30
    successThreshold: 1

route:
  enabled: true
  host: ""
  tls:
    termination: edge
  annotations:
    haproxy.router.openshift.io/timeout: "60s"
    haproxy.router.openshift.io/balance: "roundrobin"

# Security context
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  fsGroup: 1001
  seccompProfile:
    type: RuntimeDefault

# Pod Disruption Budget for high availability
podDisruptionBudget:
  enabled: false
  minAvailable: 1

# Service Monitor for Prometheus (if monitoring is enabled)
serviceMonitor:
  enabled: false
  interval: 30s
  path: /actuator/prometheus

global:  
  namespace: cf-dev
  registry: 818140567777.dkr.ecr.us-east-1.amazonaws.com/consultingfirm
```

### Step 15: Create Naming Server Deployment Template

Create `helm-charts/cf-microservices/charts/naming-server/templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: naming-server-new
  namespace: {{ .Values.global.namespace }}
  labels:
    app: naming-server-new
    app.kubernetes.io/name: {{ include "naming-server.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/version: {{ .Chart.AppVersion }}
    app.kubernetes.io/component: naming-server
    app.kubernetes.io/part-of: cf-microservices
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    service-discovery: eureka
    version: {{ .Chart.AppVersion }}
  annotations:
    description: "Naming Server (Eureka) for service discovery"
    service-discovery/port: "8761"
    service-discovery/path: "/eureka"
spec:
  replicas: {{ .Values.deployment.replicas }}
  strategy:
    type: {{ .Values.deployment.strategy.type }}
    {{- if eq .Values.deployment.strategy.type "RollingUpdate" }}
    rollingUpdate:
      maxUnavailable: {{ .Values.deployment.strategy.rollingUpdate.maxUnavailable }}
      maxSurge: {{ .Values.deployment.strategy.rollingUpdate.maxSurge }}
    {{- end }}
  selector:
    matchLabels:
      app: naming-server-new
      app.kubernetes.io/name: {{ include "naming-server.name" . }}
      app.kubernetes.io/instance: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: naming-server-new
        app.kubernetes.io/name: {{ include "naming-server.name" . }}
        app.kubernetes.io/instance: {{ .Release.Name }}
        app.kubernetes.io/version: {{ .Chart.AppVersion }}
        app.kubernetes.io/component: naming-server
        service-discovery: eureka
        version: {{ .Chart.AppVersion }}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "{{ .Values.service.targetPort }}"
        prometheus.io/path: "/actuator/prometheus"
        eureka.server/port: "{{ .Values.service.targetPort }}"
    spec:
      {{- if .Values.securityContext }}
      securityContext:
        {{- toYaml .Values.securityContext | nindent 8 }}
      {{- end }}
#      serviceAccountName: {{ .Values.global.serviceAccount }}
      {{- if .Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml .Values.global.imagePullSecrets | nindent 8 }}
      {{- end }}
      containers:
      - name: naming-server-new
        image: "{{ .Values.global.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
          name: http
        - containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
          name: eureka
        {{- if .Values.deployment.env }}
        env:
        {{- range .Values.deployment.env }}
        - name: {{ .name }}
          value: {{ .value | quote }}
        {{- end }}
        {{- end }}
        {{- with .Values.deployment.resources }}
        resources:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- if .Values.healthCheck.livenessProbe }}
        livenessProbe:
          httpGet:
            path: {{ .Values.healthCheck.livenessProbe.httpGet.path }}
            port: {{ .Values.healthCheck.livenessProbe.httpGet.port }}
          initialDelaySeconds: {{ .Values.healthCheck.livenessProbe.initialDelaySeconds }}
          periodSeconds: {{ .Values.healthCheck.livenessProbe.periodSeconds }}
          timeoutSeconds: {{ .Values.healthCheck.livenessProbe.timeoutSeconds }}
          failureThreshold: {{ .Values.healthCheck.livenessProbe.failureThreshold }}
          successThreshold: {{ .Values.healthCheck.livenessProbe.successThreshold }}
        {{- end }}
        {{- if .Values.healthCheck.readinessProbe }}
        readinessProbe:
          httpGet:
            path: {{ .Values.healthCheck.readinessProbe.httpGet.path }}
            port: {{ .Values.healthCheck.readinessProbe.httpGet.port }}
          initialDelaySeconds: {{ .Values.healthCheck.readinessProbe.initialDelaySeconds }}
          periodSeconds: {{ .Values.healthCheck.readinessProbe.periodSeconds }}
          timeoutSeconds: {{ .Values.healthCheck.readinessProbe.timeoutSeconds }}
          failureThreshold: {{ .Values.healthCheck.readinessProbe.failureThreshold }}
          successThreshold: {{ .Values.healthCheck.readinessProbe.successThreshold }}
        {{- end }}
        {{- if .Values.healthCheck.startupProbe }}
        # Startup probe for slower startup times of Eureka Server
        startupProbe:
          httpGet:
            path: {{ .Values.healthCheck.startupProbe.httpGet.path }}
            port: {{ .Values.healthCheck.startupProbe.httpGet.port }}
          initialDelaySeconds: {{ .Values.healthCheck.startupProbe.initialDelaySeconds }}
          periodSeconds: {{ .Values.healthCheck.startupProbe.periodSeconds }}
          timeoutSeconds: {{ .Values.healthCheck.startupProbe.timeoutSeconds }}
          failureThreshold: {{ .Values.healthCheck.startupProbe.failureThreshold }}
          successThreshold: {{ .Values.healthCheck.startupProbe.successThreshold }}
        {{- end }}
        # Volume mounts for configuration (if needed)
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: logs
          mountPath: /logs
      volumes:
      - name: tmp
        emptyDir: {}
      - name: logs
        emptyDir: {}
      # Pod termination grace period
      terminationGracePeriodSeconds: 30
      # DNS policy for service discovery
      dnsPolicy: ClusterFirst
      restartPolicy: Always

---
# Helper templates for naming
{{- define "naming-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "naming-server.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "naming-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "naming-server.labels" -}}
helm.sh/chart: {{ include "naming-server.chart" . }}
{{ include "naming-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "naming-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "naming-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

### Step 16: Create Naming Server Service Template

Create `helm-charts/cf-microservices/charts/naming-server/templates/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: naming-server-new
  namespace: {{ .Values.global.namespace }}
  labels:
    app: naming-server-new
    app.kubernetes.io/name: {{ include "naming-server.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/version: {{ .Chart.AppVersion }}
    app.kubernetes.io/component: naming-server
    app.kubernetes.io/part-of: cf-microservices
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    service-discovery: eureka
    version: {{ .Chart.AppVersion }}
  annotations:
    description: "Naming Server (Eureka) Service for service discovery"
    service.alpha.openshift.io/dependencies: "[]"
    prometheus.io/scrape: "true"
    prometheus.io/port: "{{ .Values.service.port }}"
    prometheus.io/path: "/actuator/prometheus"
    eureka.server/url: "http://naming-server-new:{{ .Values.service.port }}/eureka/"
    eureka.server/port: "{{ .Values.service.port }}"
spec:
  type: {{ .Values.service.type }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: {{ .Values.service.targetPort }}
    protocol: TCP
    name: http
  - port: {{ .Values.service.port }}
    targetPort: {{ .Values.service.targetPort }}
    protocol: TCP
    name: eureka
  selector:
    app: naming-server-new
    app.kubernetes.io/name: {{ include "naming-server.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800
```

### Step 17: Create Naming Server Route Template

Create `helm-charts/cf-microservices/charts/naming-server/templates/route.yaml`:

```yaml
{{- if .Values.route.enabled }}
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: naming-server-new
  namespace: {{ .Values.global.namespace }}
  labels:
    app: naming-server-new
    app.kubernetes.io/name: {{ include "naming-server.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/version: {{ .Chart.AppVersion }}
    app.kubernetes.io/component: naming-server
    app.kubernetes.io/part-of: cf-microservices
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    service-discovery: eureka
    version: {{ .Chart.AppVersion }}
  annotations:
    description: "External route for Naming Server (Eureka) service"
    eureka.server/external-url: "https://{{ .Values.route.host | default (printf "naming-server-new-%s.apps.cluster.local" .Values.global.namespace) }}"
    {{- if .Values.route.annotations }}
    {{- range $key, $value := .Values.route.annotations }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
    {{- end }}
spec:
  {{- if .Values.route.host }}
  host: {{ .Values.route.host }}
  {{- end }}
  to:
    kind: Service
    name: naming-server-new
    weight: 100
  port:
    targetPort: http
  {{- if .Values.route.tls }}
  tls:
    termination: {{ .Values.route.tls.termination }}
    {{- if .Values.route.tls.certificate }}
    certificate: {{ .Values.route.tls.certificate }}
    {{- end }}
    {{- if .Values.route.tls.key }}
    key: {{ .Values.route.tls.key }}
    {{- end }}
    {{- if .Values.route.tls.caCertificate }}
    caCertificate: {{ .Values.route.tls.caCertificate }}
    {{- end }}
    {{- if .Values.route.tls.insecureEdgeTerminationPolicy }}
    insecureEdgeTerminationPolicy: {{ .Values.route.tls.insecureEdgeTerminationPolicy }}
    {{- end }}
  {{- end }}
  wildcardPolicy: None
{{- end }}
```

### Step 18: Create Pod Disruption Budget Template (Optional)

Create `helm-charts/cf-microservices/charts/naming-server/templates/poddisruptionbudget.yaml`:

```yaml
{{- if .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: naming-server-new-pdb
  namespace: {{ .Values.global.namespace }}
  labels:
    app: naming-server-new
    app.kubernetes.io/name: {{ include "naming-server.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/component: naming-server
    service-discovery: eureka
spec:
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  selector:
    matchLabels:
      app: naming-server-new
      app.kubernetes.io/name: {{ include "naming-server.name" . }}
      app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

---

## Part 7: Creating Environment-Specific Configurations

### Step 19: Create Environment Directory Structure

```bash
# Create environment directories
mkdir -p environments/{dev,test,prod}

# Create subdirectories for each environment
for env in dev test prod; do
    mkdir -p environments/${env}/{configs,secrets}
done
```

### Step 20: Create Development Environment Configuration

Create `environments/dev/dev.yml`:

```yaml
# Development Environment Variables for CF Deployment - Naming Server Focus
---
environment_name: "dev"

# AWS Region Configuration
aws_region: "us-east-1"
supported_aws_regions:
  - "us-east-1"
  - "us-east-2"
  - "us-west-1"
  - "us-west-2"

# Availability Zone Requirements
required_availability_zones: 2
validate_availability_zones: true

# Cluster Configuration
cluster_name: "rosa-cluster"
openshift_version: "4.14"
instance_type: "m5.large"

# Naming Server Specific Configuration for Dev
naming_server_dev_config:
  replicas: 1  # Single replica for dev to save resources
  resources:
    limits:
      cpu: "500m"
      memory: "512Mi"
    requests:
      cpu: "200m"
      memory: "256Mi"
  environment_variables:
    - name: "SPRING_PROFILES_ACTIVE"
      value: "dev,openshift"
    - name: "SERVER_PORT"
      value: "8761" 
    - name: "EUREKA_CLIENT_REGISTER_WITH_EUREKA"
      value: "false"
    - name: "EUREKA_CLIENT_FETCH_REGISTRY"
      value: "false"
    - name: "EUREKA_SERVER_ENABLE_SELF_PRESERVATION"
      value: "false"
    - name: "EUREKA_SERVER_EVICTION_INTERVAL_TIMER_IN_MS"
      value: "15000"
    - name: "EUREKA_INSTANCE_HOSTNAME"
      value: "naming-server-new"
    - name: "SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL"
      value: "http://naming-server-new:8761"
    - name: "SPRING_BOOT_ADMIN_CLIENT_URL"
      value: "http://spring-boot-admin:8082"
    - name: "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE"
      value: "health,info,metrics,env,eureka"
    - name: "MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS"
      value: "always"
    - name: "LOGGING_LEVEL_COM_NETFLIX_EUREKA"
      value: "DEBUG"
    - name: "LOGGING_LEVEL_COM_NETFLIX_DISCOVERY"
      value: "DEBUG"

# Service Discovery Configuration
service_discovery_config:
  eureka_server_url: "http://naming-server-new:8761/eureka/"
  health_check_url: "http://naming-server-new:8761/actuator/health"
  info_url: "http://naming-server-new:8761/actuator/info"
  
# Autoscaling Configuration
enable_autoscaling: false  # Disabled for dev
min_replicas: 1
max_replicas: 2

# AWS Service Quotas
min_vcpu_quota: 25
validate_service_quotas: true

# ROSA CLI Validation
validate_rosa_cli: true
validate_aws_cli: true
validate_aws_credentials: true
verify_rosa_quota: false
verify_aws_permissions: false

# Validation Toggles
strict_validation: false
fail_fast: true

# Logging and Debug
enable_debug_logging: true
log_validation_results: true

# Development specific toggles
dev_mode_enabled: true
debug_endpoints_enabled: true
eureka_debug_enabled: true
```

### Step 21: Create Development Deployment Values

Create `environments/dev/deployment-values.yaml`:

```yaml
# Development Environment Values - Naming Server Focused
global:
  namespace: cf-dev
  registry: 818140567777.dkr.ecr.us-east-1.amazonaws.com/consultingfirm
  pullPolicy: Always

# Service configurations for DEV environment
namingServer:
  enabled: true
  replicas: 1  # Single replica for dev

apiGateway:
  enabled: true
  replicas: 1

springBootAdmin:
  enabled: true
  replicas: 1

configService:
  enabled: true
  replicas: 1

excelService:
  enabled: true
  replicas: 1

benchProfile:
  enabled: true
  replicas: 1

dailySubmissions:
  enabled: true
  replicas: 1

interviews:
  enabled: true
  replicas: 1

placements:
  enabled: true
  replicas: 1

frontend:
  enabled: true
  replicas: 1

# Service-specific overrides for development
# Naming Server specific configuration for development (Primary Service)
naming-server:
  deployment:
    replicas: 1
    env:
      - name: SPRING_PROFILES_ACTIVE
        value: "dev,openshift"
      - name: SERVER_PORT
        value: "8761"
      - name: EUREKA_CLIENT_REGISTER_WITH_EUREKA
        value: "false"
      - name: EUREKA_CLIENT_FETCH_REGISTRY
        value: "false"
      - name: EUREKA_SERVER_ENABLE_SELF_PRESERVATION
        value: "false"
      - name: EUREKA_SERVER_EVICTION_INTERVAL_TIMER_IN_MS
        value: "15000"
      - name: EUREKA_SERVER_RESPONSE_CACHE_UPDATE_INTERVAL_MS
        value: "5000"
      - name: EUREKA_INSTANCE_HOSTNAME
        value: "naming-server-new"
      - name: SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL
        value: "http://naming-server-new:8761"
      - name: SPRING_BOOT_ADMIN_CLIENT_URL
        value: "http://spring-boot-admin:8082"
      - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
        value: "health,info,metrics,env,eureka"
      - name: MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS
        value: "always"
      - name: LOGGING_LEVEL_COM_NETFLIX_EUREKA
        value: "DEBUG"
      - name: LOGGING_LEVEL_COM_NETFLIX_DISCOVERY
        value: "DEBUG"
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 200m
        memory: 256Mi

api-gateway:
  deployment:
    replicas: 1
    env:
      - name: EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE
        value: "http://naming-server-new:8761/eureka/"
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 200m
        memory: 256Mi

spring-boot-admin:
  deployment:
    replicas: 1
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 200m
        memory: 256Mi

# ECR Token Management Configuration for Dev Environment
ecr_token_config:
  deployment_name: "ecr-credentials-sync"
  service_account_name: "ecr-credentials-sync"
  rbac_role_name: "ecr-secret-manager"
  rbac_binding_name: "ecr-credentials-sync-binding"
  ecr_registry: "818140567777.dkr.ecr.us-east-1.amazonaws.com"
  aws_region: "us-east-1"
  iam_role_arn: "arn:aws:iam::606639739464:role/ROSAECRAssumeRole"
  secret_name: "ecr-secret"
  base_image: "amazon/aws-cli:latest"
  app_version: "1.0"
  timezone: "America/New_York"  # Dev team timezone
  refresh_interval_hours: 6
  resources:
    limits:
      cpu: "1"
      memory: "2G"
    requests:
      cpu: "500m"
      memory: "1G"

# ECR token management control (can be overridden via command line)
deploy_ecr_token_management: false
```

### Step 22: Create Test Environment Configuration

Create `environments/test/test.yml`:

```yaml
# Test Environment Variables for CF Deployment - Naming Server Focus
---
environment_name: "test"

# AWS Region Configuration
aws_region: "us-east-1"

# Naming Server Specific Configuration for Test
naming_server_test_config:
  replicas: 1  # Single replica for testing
  resources:
    limits:
      cpu: "1"
      memory: "1Gi"
    requests:
      cpu: "500m"
      memory: "512Mi"
  environment_variables:
    - name: "SPRING_PROFILES_ACTIVE"
      value: "test,openshift"
    - name: "SERVER_PORT"
      value: "8761"
    - name: "EUREKA_CLIENT_REGISTER_WITH_EUREKA"
      value: "false"
    - name: "EUREKA_CLIENT_FETCH_REGISTRY"
      value: "false"
    - name: "EUREKA_SERVER_ENABLE_SELF_PRESERVATION"
      value: "true"  # Enable for test stability
    - name: "EUREKA_SERVER_EVICTION_INTERVAL_TIMER_IN_MS"
      value: "30000"  # Longer interval for test
    - name: "EUREKA_INSTANCE_HOSTNAME"
      value: "naming-server-new"
    - name: "SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL"
      value: "http://naming-server-new:8761"
    - name: "SPRING_BOOT_ADMIN_CLIENT_URL"
      value: "http://spring-boot-admin:8082"
    - name: "LOGGING_LEVEL_COM_NETFLIX_EUREKA"
      value: "INFO"

# Service Discovery Configuration
service_discovery_config:
  eureka_server_url: "http://naming-server-new:8761/eureka/"
  health_check_url: "http://naming-server-new:8761/actuator/health"

# Autoscaling Configuration for Test
enable_autoscaling: false  # Keep simple for testing
min_replicas: 1
max_replicas: 2

# Validation Toggles
strict_validation: true
fail_fast: true

# Logging and Debug
enable_debug_logging: false
log_validation_results: true

# Test specific toggles
test_mode_enabled: true
performance_testing_enabled: true
eureka_monitoring_enabled: true
```

### Step 23: Create Production Environment Configuration

Create `environments/prod/prod.yml`:

```yaml
# Production Environment Variables for CF Deployment - Naming Server Focus
---
environment_name: "prod"

# AWS Region Configuration
aws_region: "us-east-1"

# Naming Server Specific Configuration for Production
naming_server_prod_config:
  replicas: 2  # Multiple replicas for high availability
  resources:
    limits:
      cpu: "2"
      memory: "2Gi"
    requests:
      cpu: "1"
      memory: "1Gi"
  environment_variables:
    - name: "SPRING_PROFILES_ACTIVE"
      value: "prod,openshift"
    - name: "SERVER_PORT"
      value: "8761"
    - name: "EUREKA_CLIENT_REGISTER_WITH_EUREKA"
      value: "false"
    - name: "EUREKA_CLIENT_FETCH_REGISTRY"
      value: "false"
    - name: "EUREKA_SERVER_ENABLE_SELF_PRESERVATION"
      value: "true"  # Enable for production stability
    - name: "EUREKA_SERVER_EVICTION_INTERVAL_TIMER_IN_MS"
      value: "60000"  # Longer interval for production
    - name: "EUREKA_SERVER_RESPONSE_CACHE_UPDATE_INTERVAL_MS"
      value: "30000"  # Cache optimization for production
    - name: "EUREKA_INSTANCE_HOSTNAME"
      value: "naming-server-new"
    - name: "SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL"
      value: "http://naming-server-new:8761"
    - name: "SPRING_BOOT_ADMIN_CLIENT_URL"
      value: "http://spring-boot-admin:8082"
    - name: "LOGGING_LEVEL_COM_NETFLIX_EUREKA"
      value: "WARN"
    - name: "LOGGING_LEVEL_COM_NETFLIX_DISCOVERY"  
      value: "WARN"

# Service Discovery Configuration
service_discovery_config:
  eureka_server_url: "http://naming-server-new:8761/eureka/"
  health_check_url: "http://naming-server-new:8761/actuator/health"

# Autoscaling Configuration for Production
enable_autoscaling: true
min_replicas: 2
max_replicas: 4

# Validation Toggles
strict_validation: true
fail_fast: false  # More resilient in production

# Logging and Debug
enable_debug_logging: false
log_validation_results: false

# Production specific toggles
production_mode_enabled: true
monitoring_enhanced: true
security_hardened: true
eureka_clustering_enabled: true
```

---

## Part 8: Creating the Main Playbooks

### Step 24: Create Main Naming Server Deployment Playbook

Create `playbooks/naming-server-deployment.yml`:

```yaml
---
- name: Naming Server (Eureka) Service Deployment
  hosts: localhost
  connection: local
  gather_facts: yes
  
  vars:
    # Default values that can be overridden by extra-vars
    target_environment: "{{ environment | default('dev') }}"
    service_action: "{{ action | default('deploy') }}"
    
    # Naming Server specific variables
    naming_server_only: "{{ deploy_naming_server_only | default(false) }}"
    
  pre_tasks:
    - name: Display Naming Server deployment configuration
      debug:
        msg:
          - "=== Naming Server (Eureka) Service Deployment ==="
          - "Environment: {{ target_environment }}"
          - "Action: {{ service_action }}"
          - "Deploy Naming Server Only: {{ naming_server_only }}"
          - "Namespace: cf-{{ target_environment }}"
          - "Service Discovery Port: 8761"
          - "======================================================="

    - name: Validate environment
      assert:
        that:
          - target_environment in ['dev', 'test', 'prod']
        fail_msg: "Invalid environment: {{ target_environment }}. Must be dev, test, or prod"

    - name: Set environment-specific variables
      set_fact:
        env_config_path: "{{ playbook_dir }}/../environments/{{ target_environment }}"
        values_file: "{{ playbook_dir }}/../environments/{{ target_environment }}/deployment-values.yaml"

    - name: Load environment-specific Naming Server configuration
      include_vars: "{{ env_config_path }}/{{ target_environment }}.yml"
      tags:
        - config

    - name: Display loaded configuration
      debug:
        msg:
          - "Loaded environment configuration from: {{ env_config_path }}/{{ target_environment }}.yml"
          - "Values file: {{ values_file }}"
          - "Naming Server Port: {{ service_ports.naming_server | default('8761') }}"
          - "Eureka Server URL: {{ service_discovery_config.eureka_server_url | default('http://naming-server-new:8761/eureka/') }}"
      tags:
        - config

  roles:
    - role: cf-deployment
      vars:
        env: "{{ target_environment }}"
        deploy_naming_server_only: "{{ naming_server_only }}"
        # Override with environment-specific Naming Server config
        naming_server_config: "{{ naming_server_dev_config if target_environment == 'dev' else (naming_server_test_config if target_environment == 'test' else naming_server_prod_config) }}"

  post_tasks:
    - name: Display Naming Server deployment summary
      debug:
        msg:
          - "=== Naming Server Deployment Complete ==="
          - "Environment: {{ target_environment }}"
          - "Namespace: cf-{{ target_environment }}"
          - "Status: SUCCESS"
          - "Action Performed: {{ service_action }}"
          - "Service Discovery URL: {{ service_discovery_config.eureka_server_url | default('http://naming-server-new:8761/eureka/') }}"
          - "External URL: https://naming-server-new-cf-{{ target_environment }}.apps.your-cluster.com"
          - "Health Check: https://naming-server-new-cf-{{ target_environment }}.apps.your-cluster.com/actuator/health"
          - "Eureka Dashboard: https://naming-server-new-cf-{{ target_environment }}.apps.your-cluster.com"
          - "============================================="

    - name: Provide next steps for Naming Server
      debug:
        msg:
          - "=== Next Steps ==="
          - "1. Verify Naming Server is running:"
          - "   oc get deployment naming-server-new -n cf-{{ target_environment }}"
          - "2. Check Eureka server status:"
          - "   oc logs deployment/naming-server-new -n cf-{{ target_environment }}"
          - "3. Test Eureka dashboard:"
          - "   curl https://naming-server-new-cf-{{ target_environment }}.apps.your-cluster.com"
          - "4. Test health endpoint:"
          - "   curl https://naming-server-new-cf-{{ target_environment }}.apps.your-cluster.com/actuator/health"
          - "5. Check registered services:"
          - "   curl https://naming-server-new-cf-{{ target_environment }}.apps.your-cluster.com/eureka/apps"
          - "================="
```

### Step 25: Create General Deployment Playbook with Naming Server Focus

Create `playbooks/cf-deployment.yml`:

```yaml
---
- name: CF Microservices Deployment with Naming Server
  hosts: localhost
  connection: local
  gather_facts: yes
  
  vars:
    # Default values that can be overridden by extra-vars
    target_environment: "{{ environment | default('dev') }}"
    
  pre_tasks:
    - name: Display deployment configuration
      debug:
        msg:
          - "=== CF Microservices Deployment ==="
          - "Environment: {{ target_environment }}"
          - "Namespace: cf-{{ target_environment }}"
          - "Primary Service: Naming Server (Eureka) on port 8761"
          - "Service Discovery: Enabled"
          - "======================================="

    - name: Validate environment
      assert:
        that:
          - target_environment in ['dev', 'test', 'prod']
        fail_msg: "Invalid environment: {{ target_environment }}. Must be dev, test, or prod"

    - name: Set environment-specific variables
      set_fact:
        env_config_path: "{{ playbook_dir }}/../environments/{{ target_environment }}"
        values_file: "{{ playbook_dir }}/../environments/{{ target_environment }}/deployment-values.yaml"

  roles:
    - role: cf-deployment
      vars:
        env: "{{ target_environment }}"

  post_tasks:
    - name: Display deployment summary
      debug:
        msg:
          - "=== Deployment Complete ==="
          - "Environment: {{ target_environment }}"
          - "Namespace: cf-{{ target_environment }}"
          - "Status: SUCCESS"
          - "Services Deployed:"
          - "  - Naming Server (Eureka) - Port 8761 [SERVICE DISCOVERY]"
          - "  - API Gateway - Port 8765"
          - "  - Spring Boot Admin - Port 8082"
          - "  - Config Service - Port 8888"
          - "  - Business Services - Port 8080"
          - "  - Frontend - Port 80"
          - "Service Registration URL: http://naming-server-new:8761/eureka/"
          - "========================================"
```

---

## Part 9: Usage Examples and Commands

### Step 26: Basic Usage Commands

```bash
# Deploy all services to dev environment (including Naming Server)
ansible-playbook playbooks/cf-deployment.yml -e "environment=dev"

# Deploy only Naming Server service
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=dev" \
  -e "deploy_naming_server_only=true"

# Deploy Naming Server with custom environment variables
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=dev" \
  -e "deploy_naming_server_only=true" \
  -e "naming_server_env_vars=[{'name': 'EUREKA_SERVER_ENABLE_SELF_PRESERVATION', 'value': 'true'}]"

# Deploy to production environment
ansible-playbook playbooks/cf-deployment.yml -e "environment=prod"

# Use the dedicated Naming Server playbook
ansible-playbook playbooks/naming-server-deployment.yml \
  -e "environment=dev" \
  -e "deploy_naming_server_only=true"

# Deploy with enhanced monitoring
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=dev" \
  -e "eureka_monitoring_enabled=true"
```

### Step 27: Advanced Usage with Tags

```bash
# Deploy only using specific tags
ansible-playbook playbooks/cf-deployment.yml \
  -t cf-deployment \
  -e "environment=dev"

# Deploy Naming Server with specific tag
ansible-playbook playbooks/cf-deployment.yml \
  -t naming-server \
  -e "environment=dev" \
  -e "deploy_naming_server_only=true"

# Skip certain tasks
ansible-playbook playbooks/cf-deployment.yml \
  --skip-tags ecr-token-management \
  -e "environment=dev"

# Run only validation tasks
ansible-playbook playbooks/cf-deployment.yml \
  -t validation \
  -e "environment=dev"

# Deploy with enhanced debugging
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=dev" \
  -e "enable_debug_logging=true" \
  -e "eureka_debug_enabled=true" \
  -v
```

### Step 28: Environment Variable Overrides

```bash
# Override Naming Server replicas
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=dev" \
  -e "deploy_naming_server_only=true" \
  -e "naming_server_config.replicas=2"

# Override resource limits
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=dev" \
  -e "deploy_naming_server_only=true" \
  -e "naming_server_config.resources.limits.cpu=1" \
  -e "naming_server_config.resources.limits.memory=1Gi"

# Custom Eureka server configuration
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=test" \
  -e "deploy_naming_server_only=true" \
  -e "eureka_server_config.enable_self_preservation=true"
```

---

## Part 10: Verification and Troubleshooting

### Step 29: Verification Commands

```bash
# Check Naming Server deployment status
oc get deployment naming-server-new -n cf-dev

# Check Naming Server pod status
oc get pods -l app=naming-server-new -n cf-dev

# Check Naming Server service
oc get service naming-server-new -n cf-dev

# Check Naming Server route
oc get route naming-server-new -n cf-dev

# Get detailed deployment information
oc describe deployment naming-server-new -n cf-dev

# Check Naming Server logs
oc logs deployment/naming-server-new -n cf-dev --tail=50

# Follow real-time logs
oc logs deployment/naming-server-new -n cf-dev -f

# Check events
oc get events -n cf-dev --sort-by='.lastTimestamp' | grep naming-server

# Test Eureka server health
curl -k https://$(oc get route naming-server-new -n cf-dev -o jsonpath='{.spec.host}')/actuator/health

# Check Eureka dashboard
curl -k https://$(oc get route naming-server-new -n cf-dev -o jsonpath='{.spec.host}')

# Check registered services
curl -k https://$(oc get route naming-server-new -n cf-dev -o jsonpath='{.spec.host}')/eureka/apps

# Check Eureka server info
curl -k https://$(oc get route naming-server-new -n cf-dev -o jsonpath='{.spec.host}')/actuator/info
```

### Step 30: Advanced Troubleshooting Commands

```bash
# Check Helm release status
helm list -n cf-dev

# Get Helm release details
helm get all cf-microservices-dev -n cf-dev

# Check Helm values
helm get values cf-microservices-dev -n cf-dev

# Check resource usage
oc top pods -l app=naming-server-new -n cf-dev

# Port forward for local testing
oc port-forward deployment/naming-server-new 8761:8761 -n cf-dev

# Exec into pod for debugging
oc exec -it deployment/naming-server-new -n cf-dev -- /bin/bash

# Check service endpoints
oc get endpoints naming-server-new -n cf-dev

# Describe service for detailed info
oc describe service naming-server-new -n cf-dev

# Check environment variables in pod
oc exec deployment/naming-server-new -n cf-dev -- env | grep EUREKA

# Test internal connectivity
oc exec deployment/naming-server-new -n cf-dev -- wget -qO- http://localhost:8761/actuator/health

# Check DNS resolution
oc exec deployment/naming-server-new -n cf-dev -- nslookup naming-server-new.cf-dev.svc.cluster.local
```

### Step 31: Common Issues and Solutions

#### Issue 1: Naming Server Pod Not Starting

```bash
# Check pod status and events
oc describe pod <pod-name> -n cf-dev

# Common solutions:
# 1. Check resource limits
# 2. Verify image pull secrets
# 3. Check environment variables
# 4. Verify Java memory settings

# Fix resource issues
oc patch deployment naming-server-new -n cf-dev -p '{"spec":{"template":{"spec":{"containers":[{"name":"naming-server-new","resources":{"limits":{"memory":"1Gi"}}}]}}}}'
```

#### Issue 2: Eureka Server Not Accepting Registrations

```bash
# Check Eureka server configuration
oc logs deployment/naming-server-new -n cf-dev | grep -i eureka

# Verify environment variables
oc describe deployment naming-server-new -n cf-dev | grep -A 10 Environment

# Test Eureka server endpoints
curl -k https://$(oc get route naming-server-new -n cf-dev -o jsonpath='{.spec.host}')/eureka/apps
```

#### Issue 3: Service Discovery Issues

```bash
# Check if services can reach Naming Server
oc exec deployment/api-gateway-app -n cf-dev -- nslookup naming-server-new.cf-dev.svc.cluster.local

# Verify service registration
curl -k https://$(oc get route naming-server-new -n cf-dev -o jsonpath='{.spec.host}')/eureka/apps | jq .

# Check Eureka client logs in other services
oc logs deployment/api-gateway-app -n cf-dev | grep -i eureka
```

---

## Part 11: Directory Structure Summary

Your final directory structure should look like this:

```
ansible-project/
├── playbooks/
│   ├── cf-deployment.yml
│   └── naming-server-deployment.yml
├── roles/
│   └── cf-deployment/
│       ├── defaults/
│       │   └── main.yml
│       ├── tasks/
│       │   ├── main.yml
│       │   ├── validate_prerequisites.yml
│       │   ├── cf-namespace.yml
│       │   ├── cf-microservices.yml
│       │   ├── naming-server-validations.yml
│       │   └── ecr-token-management.yml
│       ├── vars/
│       │   └── main.yml
│       ├── templates/
│       ├── handlers/
│       ├── meta/
│       │   └── main.yml
│       ├── Doc-deployment/
│       │   └── Naming-Server-Deployment-Guide.md
│       └── execution/
├── helm-charts/
│   └── cf-microservices/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── templates/
│       └── charts/
│           └── naming-server/
│               ├── Chart.yaml
│               ├── values.yaml
│               └── templates/
│                   ├── deployment.yaml
│                   ├── service.yaml
│                   ├── route.yaml
│                   └── poddisruptionbudget.yaml
└── environments/
    ├── dev/
    │   ├── dev.yml
    │   ├── deployment-values.yaml
    │   └── configs/
    ├── test/
    │   ├── test.yml
    │   ├── deployment-values.yaml
    │   └── configs/
    └── prod/
        ├── prod.yml
        ├── deployment-values.yaml
        └── configs/
```

---

## Conclusion

This comprehensive guide provides a complete, step-by-step process for creating an Ansible role that deploys Naming Server (Eureka Service Discovery) using Helm charts on OpenShift/Kubernetes. The implementation includes:

### Key Features:

- **Complete Eureka Server Implementation**: Service running on port 8761 with proper configuration
- **Service Discovery Setup**: Full Eureka server configuration for microservices registration
- **Spring Boot Admin Integration**: Monitoring and management capabilities
- **Environment Variable Support**: Dynamic configuration through external variables  
- **Health Checks**: Comprehensive liveness, readiness, and startup probes
- **Resource Management**: Proper CPU and memory limits for different environments
- **External Access**: OpenShift routes with TLS termination
- **Validation Framework**: Pre and post deployment validations
- **Troubleshooting Support**: Comprehensive debugging and monitoring capabilities
- **Environment Separation**: Proper dev/test/prod configurations
- **High Availability**: Pod disruption budgets and clustering support

### Advanced Capabilities:

- **Zero-Downtime Deployments**: Rolling updates with proper health checks
- **Self-Preservation Configuration**: Environment-specific Eureka settings
- **Monitoring Integration**: Prometheus metrics and Spring Boot Admin
- **Security Context**: Proper security configurations
- **Service Registration Validation**: Comprehensive service discovery testing
- **Multi-Environment Support**: Different configurations for dev/test/prod

This implementation follows industry best practices and provides a production-ready deployment system for Naming Server (Eureka) in a microservices architecture, serving as the foundation for service discovery across all microservices.