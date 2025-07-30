# API Gateway Service Deployment Guide
## Complete Step-by-Step Tutorial for Beginners

This comprehensive guide will walk you through creating a complete Ansible role for deploying API Gateway service using Helm charts on OpenShift/Kubernetes. You'll learn how to create the entire directory structure and write all the code from scratch, exactly as implemented in our current system.

## Prerequisites

- Basic understanding of Ansible, Helm, and Kubernetes/OpenShift
- Access to an OpenShift/Kubernetes cluster
- Helm CLI installed (version 3.x)
- OpenShift CLI (oc) installed
- Ansible installed with kubernetes.core collection

## Overview

We'll create a complete deployment system including:
1. Ansible role structure for cf-deployment
2. Helm chart specifically for API Gateway service
3. Environment-specific configurations
4. Service-to-service communication setup
5. Port configuration and environment variables
6. Deployment automation with external variable support

---

## Part 1: Understanding the API Gateway Architecture

### API Gateway Service Details
- **Service Name**: `apigateway-app`
- **Port**: `8765` (updated from default 8080)
- **Purpose**: Central entry point for microservices
- **Dependencies**: 
  - Naming Server (Eureka) for service discovery
  - Spring Boot Admin for monitoring
- **Container Image**: `api-gateway-service:latest`

### Key Features We'll Implement
- **Environment Variable Support**: Dynamic configuration
- **Service Discovery Integration**: Eureka registration
- **Health Checks**: Kubernetes liveness/readiness probes
- **External Access**: OpenShift routes
- **Resource Management**: CPU/Memory limits
- **Rolling Updates**: Zero-downtime deployments

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
  description: ConsultingFirm microservices deployment role with API Gateway support
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
    - api-gateway
    - openshift
    - kubernetes
    - helm
    - spring-boot

dependencies:
  - name: kubernetes.core
    version: ">=2.3.0"
```

### Step 3: Create Default Variables for API Gateway

Create `roles/cf-deployment/defaults/main.yml`:

```yaml
---
# Default variables for CF Deployment Role with API Gateway focus

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

# API Gateway specific configuration
api_gateway_config:
  enabled: true
  replicas: 2
  port: 8765
  targetPort: 8765
  image:
    repository: "api-gateway-service"
    tag: "latest"
    pullPolicy: "Always"
  resources:
    limits:
      cpu: "1"
      memory: "1Gi"
    requests:
      cpu: "500m"
      memory: "512Mi"
  environment_variables:
    - name: "SPRING_PROFILES_ACTIVE"
      value: "openshift"
    - name: "SERVER_PORT"
      value: "8765"
    - name: "EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE"
      value: "http://naming-server-new:8761/eureka/"
    - name: "SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL"
      value: "http://apigateway-app:8765"
    - name: "SPRING_BOOT_ADMIN_CLIENT_URL"
      value: "http://spring-boot-admin:8082"

# Deployment timeouts (in seconds)
helm_timeout: 600
deployment_wait_timeout: 600

# Verification settings
verify_deployment: true
show_deployment_status: true

# Health check configuration
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

# Route configuration for external access
route_config:
  enabled: true
  tls:
    termination: "edge"
  annotations: {}

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
  base_image: "your-registry/base-image:latest"
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
# Internal variables for CF Deployment Role - API Gateway Focus

# Supported environments
supported_environments:
  - dev
  - test
  - prod

# Service port mappings - Updated for API Gateway
service_ports:
  naming_server: 8761
  api_gateway: 8765  # Updated from 8080 to 8765
  spring_boot_admin: 8082
  config_service: 8888
  excel_service: 8080
  bench_profile: 8080
  daily_submissions: 8080
  interviews: 8080
  placements: 8080
  frontend: 80

# API Gateway specific variables
api_gateway_vars:
  service_name: "apigateway-app"
  app_label: "apigateway-app"
  chart_name: "api-gateway"
  default_replicas: 2
  min_replicas: 1
  max_replicas: 5

# Resource configurations for different environments
resource_profiles:
  dev:
    api_gateway:
      limits:
        cpu: "500m"
        memory: "512Mi"
      requests:
        cpu: "200m"
        memory: "256Mi"
  test:
    api_gateway:
      limits:
        cpu: "1"
        memory: "1Gi"
      requests:
        cpu: "500m"
        memory: "512Mi"
  prod:
    api_gateway:
      limits:
        cpu: "2"
        memory: "2Gi"
      requests:
        cpu: "1"
        memory: "1Gi"

# Service dependencies for API Gateway
service_dependencies:
  required:
    - naming_server
  optional:
    - spring_boot_admin
    - config_service

# Deployment strategies
deployment_strategies:
  rolling_update:
    max_unavailable: 1
    max_surge: 1
  recreate: {}
```

---

## Part 3: Creating the Core Tasks

### Step 5: Create Main Task Orchestration

Create `roles/cf-deployment/tasks/main.yml`:

```yaml
---
# CF Deployment Role - Main Tasks with API Gateway Focus
# Deploy ConsultingFirm microservices using Helm charts

- name: CF Deployment - Start orchestration
  debug:
    msg:
      - "Starting CF Deployment orchestration"
      - "Environment: {{ cf_environment }}"
      - "Namespace: {{ cf_namespace }}"
      - "Release: {{ cf_release_name }}"
      - "API Gateway Configuration:"
      - "  Port: {{ api_gateway_config.port }}"
      - "  Replicas: {{ api_gateway_config.replicas }}"
      - "  Image: {{ api_gateway_config.image.repository }}:{{ api_gateway_config.image.tag }}"
  tags:
    - cf-deployment
    - deployment
    - microservices
    - orchestration
    - api-gateway

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
    - api-gateway

- name: Include API Gateway Specific Validations
  include_tasks: api-gateway-validations.yml
  when: 
    - api_gateway_config.enabled | bool
    - verify_deployment | bool
  tags:
    - cf-deployment
    - api-gateway
    - validation
    - verify

- name: CF Deployment - Orchestration completed
  debug:
    msg:
      - "CF Deployment orchestration completed successfully"
      - "Environment: {{ cf_environment }}"
      - "Namespace: {{ cf_namespace }}"
      - "Release: {{ cf_release_name }}"
      - "API Gateway Status: {{ 'Deployed' if api_gateway_config.enabled else 'Skipped' }}"
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
# CF Deployment Role - Prerequisites Validation for API Gateway

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

- name: Display API Gateway configuration summary
  debug:
    msg:
      - "=== API Gateway Configuration Summary ==="
      - "Service Name: {{ api_gateway_vars.service_name }}"
      - "Port: {{ api_gateway_config.port }}"
      - "Target Port: {{ api_gateway_config.targetPort }}"
      - "Replicas: {{ api_gateway_config.replicas }}"
      - "Image: {{ api_gateway_config.image.repository }}:{{ api_gateway_config.image.tag }}"
      - "Resources:"
      - "  CPU Limit: {{ api_gateway_config.resources.limits.cpu }}"
      - "  Memory Limit: {{ api_gateway_config.resources.limits.memory }}"
      - "  CPU Request: {{ api_gateway_config.resources.requests.cpu }}"
      - "  Memory Request: {{ api_gateway_config.resources.requests.memory }}"
      - "Environment Variables: {{ api_gateway_config.environment_variables | length }} configured"
      - "============================================="
  tags:
    - validation
    - prerequisites
    - api-gateway
```

### Step 7: Create Namespace Management Task

Create `roles/cf-deployment/tasks/cf-namespace.yml`:

```yaml
---
# CF Deployment Role - Namespace Management for API Gateway

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
      - "Services to be deployed: API Gateway and dependencies"
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
          component: "api-gateway"
        annotations:
          description: "ConsultingFirm microservices namespace for {{ cf_environment }} environment"
          "openshift.io/display-name": "CF Microservices - {{ cf_environment | title }}"
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
  tags:
    - cf-deployment
    - cf-namespace  
    - namespace
    - verify

- name: Namespace creation completed
  debug:
    msg: "Namespace {{ cf_namespace }} is ready for API Gateway and microservices deployments"
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
# CF Deployment Role - Helm Integration for API Gateway
# Deploy ConsultingFirm microservices using Helm charts with API Gateway focus

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
      # Override API Gateway configuration
      api-gateway:
        service:
          port: "{{ api_gateway_config.port }}"
          targetPort: "{{ api_gateway_config.targetPort }}"
        deployment:
          replicas: "{{ api_gateway_config.replicas }}"
          env: "{{ api_gateway_config.environment_variables }}"
          resources: "{{ api_gateway_config.resources }}"
        image:
          repository: "{{ api_gateway_config.image.repository }}"
          tag: "{{ api_gateway_config.image.tag }}"
          pullPolicy: "{{ api_gateway_config.image.pullPolicy }}"
        route:
          enabled: "{{ route_config.enabled }}"
          tls:
            termination: "{{ route_config.tls.termination }}"
    state: present
    wait: true
    wait_timeout: "{{ helm_timeout }}s"
    force: true
  when: not (deploy_api_gateway_only | default(false))
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

# API Gateway Only Deployment Task
- name: Deploy API Gateway only
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
        enabled: false
      apiGateway:
        enabled: true
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
      # Override API Gateway specific configuration
      api-gateway:
        service:
          port: "{{ api_gateway_config.port }}"
          targetPort: "{{ api_gateway_config.targetPort }}"
        deployment:
          replicas: "{{ api_gateway_config.replicas }}"
          env: "{{ api_gateway_config.environment_variables }}"
          resources: "{{ api_gateway_config.resources }}"
        image:
          repository: "{{ api_gateway_config.image.repository }}"
          tag: "{{ api_gateway_config.image.tag }}"
          pullPolicy: "{{ api_gateway_config.image.pullPolicy }}"
        route:
          enabled: "{{ route_config.enabled }}"
          tls:
            termination: "{{ route_config.tls.termination }}"
    state: present
    wait: true
    wait_timeout: 300s
  when: deploy_api_gateway_only | default(false)
  tags:
    - cf-deployment
    - deployment
    - cf-api-gateway
    - api-gateway

- name: Verify API Gateway deployment (when deployed individually)
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    name: "{{ api_gateway_vars.service_name }}"
    namespace: "{{ cf_namespace }}"
    wait: true
    wait_condition:
      type: Available
      status: "True"
    wait_timeout: 300
  register: api_gateway_deployment_status
  when: 
    - deploy_api_gateway_only | default(false)
    - verify_deployment | bool
  tags:
    - cf-deployment
    - deployment
    - cf-api-gateway
    - api-gateway
    - verify

- name: Display API Gateway deployment status
  debug:
    msg:
      - "API Gateway Deployment Status:"
      - "  Name: {{ api_gateway_vars.service_name }}"
      - "  Namespace: {{ cf_namespace }}"
      - "  Ready Replicas: {{ api_gateway_deployment_status.resources[0].status.readyReplicas | default(0) }}"
      - "  Available Replicas: {{ api_gateway_deployment_status.resources[0].status.availableReplicas | default(0) }}"
      - "  Desired Replicas: {{ api_gateway_deployment_status.resources[0].status.replicas | default(0) }}"
  when: 
    - deploy_api_gateway_only | default(false)
    - verify_deployment | bool
    - api_gateway_deployment_status is defined
  tags:
    - cf-deployment
    - deployment
    - cf-api-gateway
    - api-gateway
    - verify
```

### Step 9: Create API Gateway Validation Task

Create `roles/cf-deployment/tasks/api-gateway-validations.yml`:

```yaml
---
# CF Deployment Role - API Gateway Specific Validations

- name: Get API Gateway deployment status
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    name: "{{ api_gateway_vars.service_name }}"
    namespace: "{{ cf_namespace }}"
  register: api_gateway_deployment
  tags:
    - validation
    - api-gateway
    - verify

- name: Get API Gateway service status
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Service
    name: "{{ api_gateway_vars.service_name }}"
    namespace: "{{ cf_namespace }}"
  register: api_gateway_service
  tags:
    - validation
    - api-gateway
    - verify

- name: Get API Gateway route status
  kubernetes.core.k8s_info:
    api_version: route.openshift.io/v1
    kind: Route
    name: "{{ api_gateway_vars.service_name }}"
    namespace: "{{ cf_namespace }}"
  register: api_gateway_route
  ignore_errors: true
  tags:
    - validation
    - api-gateway
    - verify

- name: Get API Gateway pods
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Pod
    namespace: "{{ cf_namespace }}"
    label_selectors:
      - "app={{ api_gateway_vars.app_label }}"
  register: api_gateway_pods
  tags:
    - validation
    - api-gateway
    - verify

- name: Validate API Gateway deployment
  assert:
    that:
      - api_gateway_deployment.resources | length > 0
      - api_gateway_deployment.resources[0].status.readyReplicas | default(0) > 0
    fail_msg: "API Gateway deployment is not ready"
    success_msg: "API Gateway deployment is healthy"
  tags:
    - validation
    - api-gateway
    - verify

- name: Validate API Gateway service
  assert:
    that:
      - api_gateway_service.resources | length > 0
      - api_gateway_service.resources[0].spec.ports[0].port == api_gateway_config.port
    fail_msg: "API Gateway service is not properly configured"
    success_msg: "API Gateway service is properly configured"
  tags:
    - validation
    - api-gateway
    - verify

- name: Display API Gateway validation summary
  debug:
    msg:
      - "=== API Gateway Validation Summary ==="
      - "Deployment Status: {{ 'Ready' if api_gateway_deployment.resources[0].status.readyReplicas | default(0) > 0 else 'Not Ready' }}"
      - "Ready Replicas: {{ api_gateway_deployment.resources[0].status.readyReplicas | default(0) }}/{{ api_gateway_deployment.resources[0].spec.replicas | default(0) }}"
      - "Service Port: {{ api_gateway_service.resources[0].spec.ports[0].port if api_gateway_service.resources else 'N/A' }}"
      - "Target Port: {{ api_gateway_service.resources[0].spec.ports[0].targetPort if api_gateway_service.resources else 'N/A' }}"
      - "Running Pods: {{ api_gateway_pods.resources | selectattr('status.phase', 'equalto', 'Running') | list | length }}"
      - "External Route: {{ 'Available' if api_gateway_route.resources else 'Not Available' }}"
      - "Route URL: {{ api_gateway_route.resources[0].spec.host if api_gateway_route.resources else 'N/A' }}"
      - "======================================="
  tags:
    - validation
    - api-gateway  
    - verify

- name: Check API Gateway pod logs for errors (if pods are not ready)
  kubernetes.core.k8s_log:
    api_version: v1
    kind: Pod
    namespace: "{{ cf_namespace }}"
    name: "{{ item.metadata.name }}"
    tail_lines: 20
  register: pod_logs
  loop: "{{ api_gateway_pods.resources }}"
  when: 
    - api_gateway_pods.resources | length > 0
    - item.status.phase != 'Running' or item.status.containerStatuses[0].ready == false
  ignore_errors: true
  tags:
    - validation
    - api-gateway
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
    - api-gateway
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
mkdir -p helm-charts/cf-microservices/charts/api-gateway/{templates,charts}

# Create templates directory for individual charts
mkdir -p helm-charts/cf-microservices/charts/api-gateway/templates
```

### Step 11: Create Main Helm Chart Configuration

Create `helm-charts/cf-microservices/Chart.yaml`:

```yaml
apiVersion: v2
name: cf-microservices
description: ConsultingFirm Microservices Helm Chart with API Gateway
type: application
version: 1.0.0
appVersion: "1.0.0"
keywords:
  - microservices
  - spring-boot
  - api-gateway
  - consulting-firm
  - spring-cloud
home: https://consultingfirm.com
sources:
  - https://github.com/consultingfirm/microservices
maintainers:
  - name: DevOps Team
    email: devops@consultingfirm.com
  - name: API Gateway Team
    email: api-gateway@consultingfirm.com
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

### Step 12: Create Main Helm Values File with API Gateway Focus

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
naming-server:
  image:
    repository: naming-server-service
    tag: latest
  service:
    port: 8761
  deployment:
    replicas: 1
  route:
    enabled: true
    tls:
      termination: edge

# API Gateway Configuration (Updated for port 8765)
api-gateway:
  image:
    repository: api-gateway-service
    tag: latest
  service:
    port: 8765  # Updated from 8080 to 8765
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
    port: 8082  # Updated from 8080 to 8082
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

## Part 6: Creating API Gateway Specific Helm Chart

### Step 13: Create API Gateway Chart Configuration

Create `helm-charts/cf-microservices/charts/api-gateway/Chart.yaml`:

```yaml
apiVersion: v2
name: api-gateway
description: API Gateway Service Helm Chart for Spring Cloud Gateway
type: application
version: 1.0.0
appVersion: "2.7.0"
keywords:
  - api-gateway
  - spring-cloud-gateway
  - microservices
  - routing
  - load-balancing
home: https://spring.io/projects/spring-cloud-gateway
sources:
  - https://github.com/spring-cloud/spring-cloud-gateway
maintainers:
  - name: API Gateway Team
    email: api-gateway@consultingfirm.com
  - name: DevOps Team
    email: devops@consultingfirm.com
annotations:
  category: Microservices
  licenses: Apache-2.0
```

### Step 14: Create API Gateway Values with Environment Variables

Create `helm-charts/cf-microservices/charts/api-gateway/values.yaml`:

```yaml
image:
  repository: api-gateway-service
  tag: latest
  pullPolicy: Always

service:
  type: ClusterIP
  port: 8765      # Updated from 8080 to 8765
  targetPort: 8765 # Updated from 8080 to 8765

deployment:
  replicas: 2
  # Environment variables for API Gateway configuration
  env:
    - name: SPRING_PROFILES_ACTIVE
      value: "openshift"
    - name: SERVER_PORT
      value: "8765"
    - name: EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE
      value: "http://naming-server-new:8761/eureka/"
    - name: SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL
      value: "http://apigateway-app:8765"
    - name: SPRING_BOOT_ADMIN_CLIENT_URL
      value: "http://spring-boot-admin:8082"
    - name: SPRING_CLOUD_GATEWAY_ENABLED
      value: "true"
    - name: SPRING_CLOUD_GATEWAY_DISCOVERY_LOCATOR_ENABLED
      value: "true"
    - name: SPRING_CLOUD_GATEWAY_DISCOVERY_LOCATOR_LOWER_CASE_SERVICE_ID
      value: "true"
    - name: LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_CLOUD_GATEWAY
      value: "DEBUG"
    - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
      value: "health,info,gateway"
    - name: MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS
      value: "always"
  resources:
    limits:
      cpu: 1
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi
  # Deployment strategy
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1

# Health check configuration
healthCheck:
  livenessProbe:
    httpGet:
      path: /actuator/health
      port: 8765
    initialDelaySeconds: 60
    periodSeconds: 30
    timeoutSeconds: 10
    failureThreshold: 3
    successThreshold: 1
  readinessProbe:
    httpGet:
      path: /actuator/health
      port: 8765
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
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

global:  
  namespace: cf-dev
  registry: 818140567777.dkr.ecr.us-east-1.amazonaws.com/consultingfirm
```

### Step 15: Create API Gateway Deployment Template

Create `helm-charts/cf-microservices/charts/api-gateway/templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apigateway-app
  namespace: {{ .Values.global.namespace }}
  labels:
    app: apigateway-app
    app.kubernetes.io/name: {{ include "api-gateway.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/version: {{ .Chart.AppVersion }}
    app.kubernetes.io/component: api-gateway
    app.kubernetes.io/part-of: cf-microservices
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    version: {{ .Chart.AppVersion }}
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
      app: apigateway-app
      app.kubernetes.io/name: {{ include "api-gateway.name" . }}
      app.kubernetes.io/instance: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: apigateway-app
        app.kubernetes.io/name: {{ include "api-gateway.name" . }}
        app.kubernetes.io/instance: {{ .Release.Name }}
        app.kubernetes.io/version: {{ .Chart.AppVersion }}
        app.kubernetes.io/component: api-gateway
        version: {{ .Chart.AppVersion }}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "{{ .Values.service.targetPort }}"
        prometheus.io/path: "/actuator/prometheus"
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
      - name: apigateway-app
        image: "{{ .Values.global.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
          name: http
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
        # Startup probe for slower startup times
        startupProbe:
          httpGet:
            path: /actuator/health
            port: {{ .Values.service.targetPort }}
          initialDelaySeconds: 20
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 30
          successThreshold: 1
      # Pod termination grace period
      terminationGracePeriodSeconds: 30
      # DNS policy for service discovery
      dnsPolicy: ClusterFirst
      restartPolicy: Always

---
# Helper template for naming
{{- define "api-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "api-gateway.fullname" -}}
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

{{- define "api-gateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "api-gateway.labels" -}}
helm.sh/chart: {{ include "api-gateway.chart" . }}
{{ include "api-gateway.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "api-gateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "api-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

### Step 16: Create API Gateway Service Template

Create `helm-charts/cf-microservices/charts/api-gateway/templates/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: apigateway-app
  namespace: {{ .Values.global.namespace }}
  labels:
    app: apigateway-app
    app.kubernetes.io/name: {{ include "api-gateway.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/version: {{ .Chart.AppVersion }}
    app.kubernetes.io/component: api-gateway
    app.kubernetes.io/part-of: cf-microservices
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    version: {{ .Chart.AppVersion }}
  annotations:
    description: "API Gateway Service for ConsultingFirm microservices"
    service.alpha.openshift.io/dependencies: '[{"name": "naming-server-new", "kind": "Service"}]'
    prometheus.io/scrape: "true"
    prometheus.io/port: "{{ .Values.service.port }}"
    prometheus.io/path: "/actuator/prometheus"
spec:
  type: {{ .Values.service.type }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: {{ .Values.service.targetPort }}
    protocol: TCP
    name: http
  selector:
    app: apigateway-app
    app.kubernetes.io/name: {{ include "api-gateway.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
  sessionAffinity: None
```

### Step 17: Create API Gateway Route Template

Create `helm-charts/cf-microservices/charts/api-gateway/templates/route.yaml`:

```yaml
{{- if .Values.route.enabled }}
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: apigateway-app
  namespace: {{ .Values.global.namespace }}
  labels:
    app: apigateway-app
    app.kubernetes.io/name: {{ include "api-gateway.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/version: {{ .Chart.AppVersion }}
    app.kubernetes.io/component: api-gateway
    app.kubernetes.io/part-of: cf-microservices
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    version: {{ .Chart.AppVersion }}
  annotations:
    description: "External route for API Gateway service"
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
    name: apigateway-app
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

---

## Part 7: Creating Environment-Specific Configurations

### Step 18: Create Environment Directory Structure

```bash
# Create environment directories
mkdir -p environments/{dev,test,prod}

# Create subdirectories for each environment
for env in dev test prod; do
    mkdir -p environments/${env}/{configs,secrets}
done
```

### Step 19: Create Development Environment Configuration

Create `environments/dev/dev.yml`:

```yaml
# Development Environment Variables for CF Deployment - API Gateway Focus
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

# API Gateway Specific Configuration for Dev
api_gateway_dev_config:
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
      value: "8765"
    - name: "LOGGING_LEVEL_ROOT"
      value: "INFO"
    - name: "LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_CLOUD_GATEWAY"
      value: "DEBUG"
    - name: "EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE"
      value: "http://naming-server-new:8761/eureka/"
    - name: "SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL"
      value: "http://apigateway-app:8765"
    - name: "SPRING_BOOT_ADMIN_CLIENT_URL"
      value: "http://spring-boot-admin:8082"
    - name: "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE"
      value: "health,info,gateway,routes,refresh"
    - name: "MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS"
      value: "always"

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
```

### Step 20: Create Development Deployment Values

Create `environments/dev/deployment-values.yaml`:

```yaml
# Development Environment Values - API Gateway Focused
global:
  namespace: cf-dev
  registry: 818140567777.dkr.ecr.us-east-1.amazonaws.com/consultingfirm
  pullPolicy: Always

# Service configurations for DEV environment
namingServer:
  enabled: true
  replicas: 1

apiGateway:
  enabled: true
  replicas: 1  # Single replica for dev

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
naming-server:
  deployment:
    replicas: 1
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 200m
        memory: 256Mi

# API Gateway specific configuration for development
api-gateway:
  deployment:
    replicas: 1
    env:
      - name: SPRING_PROFILES_ACTIVE
        value: "dev,openshift"
      - name: SERVER_PORT
        value: "8765"
      - name: EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE
        value: "http://naming-server-new:8761/eureka/"
      - name: SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL
        value: "http://apigateway-app:8765"
      - name: SPRING_BOOT_ADMIN_CLIENT_URL
        value: "http://spring-boot-admin:8082"
      - name: SPRING_CLOUD_GATEWAY_ENABLED
        value: "true"
      - name: SPRING_CLOUD_GATEWAY_DISCOVERY_LOCATOR_ENABLED
        value: "true"
      - name: SPRING_CLOUD_GATEWAY_DISCOVERY_LOCATOR_LOWER_CASE_SERVICE_ID
        value: "true"
      - name: LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_CLOUD_GATEWAY
        value: "DEBUG"
      - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
        value: "health,info,gateway,routes,refresh"
      - name: MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS
        value: "always"
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

### Step 21: Create Test Environment Configuration

Create `environments/test/test.yml`:

```yaml
# Test Environment Variables for CF Deployment - API Gateway Focus
---
environment_name: "test"

# AWS Region Configuration
aws_region: "us-east-1"

# API Gateway Specific Configuration for Test
api_gateway_test_config:
  replicas: 2  # Slightly more replicas for testing
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
      value: "8765"
    - name: "LOGGING_LEVEL_ROOT"
      value: "WARN"
    - name: "LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_CLOUD_GATEWAY"
      value: "INFO"
    - name: "EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE"
      value: "http://naming-server-new:8761/eureka/"
    - name: "SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL"
      value: "http://apigateway-app:8765"
    - name: "SPRING_BOOT_ADMIN_CLIENT_URL"
      value: "http://spring-boot-admin:8082"

# Autoscaling Configuration for Test
enable_autoscaling: true
min_replicas: 2
max_replicas: 4

# Validation Toggles
strict_validation: true
fail_fast: true

# Logging and Debug
enable_debug_logging: false
log_validation_results: true

# Test specific toggles
test_mode_enabled: true
performance_testing_enabled: true
```

### Step 22: Create Production Environment Configuration

Create `environments/prod/prod.yml`:

```yaml
# Production Environment Variables for CF Deployment - API Gateway Focus
---
environment_name: "prod"

# AWS Region Configuration
aws_region: "us-east-1"

# API Gateway Specific Configuration for Production
api_gateway_prod_config:
  replicas: 3  # Multiple replicas for high availability
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
      value: "8765"
    - name: "LOGGING_LEVEL_ROOT"
      value: "WARN"
    - name: "LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_CLOUD_GATEWAY"
      value: "INFO"
    - name: "EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE"
      value: "http://naming-server-new:8761/eureka/"
    - name: "SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL"
      value: "http://apigateway-app:8765"
    - name: "SPRING_BOOT_ADMIN_CLIENT_URL"
      value: "http://spring-boot-admin:8082"

# Autoscaling Configuration for Production
enable_autoscaling: true
min_replicas: 3
max_replicas: 10

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
```

---

## Part 8: Creating the Main Playbook

### Step 23: Create Main API Gateway Deployment Playbook

Create `playbooks/api-gateway-deployment.yml`:

```yaml
---
- name: API Gateway Service Deployment
  hosts: localhost
  connection: local
  gather_facts: yes
  
  vars:
    # Default values that can be overridden by extra-vars
    target_environment: "{{ environment | default('dev') }}"
    service_action: "{{ action | default('deploy') }}"
    
    # API Gateway specific variables
    api_gateway_only: "{{ deploy_api_gateway_only | default(false) }}"
    
  pre_tasks:
    - name: Display API Gateway deployment configuration
      debug:
        msg:
          - "=== API Gateway Service Deployment ==="
          - "Environment: {{ target_environment }}"
          - "Action: {{ service_action }}"
          - "Deploy API Gateway Only: {{ api_gateway_only }}"
          - "Namespace: cf-{{ target_environment }}"
          - "========================================"

    - name: Validate environment
      assert:
        that:
          - target_environment in ['dev', 'test', 'prod']
        fail_msg: "Invalid environment: {{ target_environment }}. Must be dev, test, or prod"

    - name: Set environment-specific variables
      set_fact:
        env_config_path: "{{ playbook_dir }}/../environments/{{ target_environment }}"
        values_file: "{{ playbook_dir }}/../environments/{{ target_environment }}/deployment-values.yaml"

    - name: Load environment-specific API Gateway configuration
      include_vars: "{{ env_config_path }}/{{ target_environment }}.yml"
      tags:
        - config

    - name: Display loaded configuration
      debug:
        msg:
          - "Loaded environment configuration from: {{ env_config_path }}/{{ target_environment }}.yml"
          - "Values file: {{ values_file }}"
          - "API Gateway Port: {{ service_ports.api_gateway | default('8765') }}"
      tags:
        - config

  roles:
    - role: cf-deployment
      vars:
        env: "{{ target_environment }}"
        deploy_api_gateway_only: "{{ api_gateway_only }}"
        # Override with environment-specific API Gateway config
        api_gateway_config: "{{ api_gateway_dev_config if target_environment == 'dev' else (api_gateway_test_config if target_environment == 'test' else api_gateway_prod_config) }}"

  post_tasks:
    - name: Display API Gateway deployment summary
      debug:
        msg:
          - "=== API Gateway Deployment Complete ==="
          - "Environment: {{ target_environment }}"
          - "Namespace: cf-{{ target_environment }}"
          - "Status: SUCCESS"
          - "Action Performed: {{ service_action }}"
          - "API Gateway URL: https://apigateway-app-cf-{{ target_environment }}.apps.your-cluster.com"
          - "Health Check: https://apigateway-app-cf-{{ target_environment }}.apps.your-cluster.com/actuator/health"
          - "Gateway Routes: https://apigateway-app-cf-{{ target_environment }}.apps.your-cluster.com/actuator/gateway/routes"
          - "=========================================="

    - name: Provide next steps
      debug:
        msg:
          - "=== Next Steps ==="
          - "1. Verify API Gateway is running:"
          - "   oc get deployment apigateway-app -n cf-{{ target_environment }}"
          - "2. Check pod logs:"
          - "   oc logs deployment/apigateway-app -n cf-{{ target_environment }}"
          - "3. Test health endpoint:"
          - "   curl https://apigateway-app-cf-{{ target_environment }}.apps.your-cluster.com/actuator/health"
          - "4. View gateway routes:"
          - "   curl https://apigateway-app-cf-{{ target_environment }}.apps.your-cluster.com/actuator/gateway/routes"
          - "=================="
```

### Step 24: Create General Deployment Playbook

Create `playbooks/cf-deployment.yml`:

```yaml
---
- name: CF Microservices Deployment with API Gateway
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
          - "API Gateway Port: 8765"
          - "====================================="

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
          - "  - API Gateway (Port 8765)"
          - "  - Spring Boot Admin (Port 8082)"
          - "  - Naming Server (Port 8761)"
          - "  - Config Service (Port 8888)"
          - "  - Business Services (Port 8080)"
          - "  - Frontend (Port 80)"
          - "=============================="
```

---

## Part 9: Usage Examples and Commands

### Step 25: Basic Usage Commands

```bash
# Deploy all services to dev environment
ansible-playbook playbooks/cf-deployment.yml -e "environment=dev"

# Deploy only API Gateway service
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=dev" \
  -e "deploy_api_gateway_only=true"

# Deploy API Gateway with custom environment variables
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=dev" \
  -e "deploy_api_gateway_only=true" \
  -e "api_gateway_env_vars=[{'name': 'CUSTOM_VAR', 'value': 'custom_value'}]"

# Deploy to production environment
ansible-playbook playbooks/cf-deployment.yml -e "environment=prod"

# Deploy with ECR token management enabled
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=dev" \
  -e "deploy_ecr_token_management=true"

# Use the dedicated API Gateway playbook
ansible-playbook playbooks/api-gateway-deployment.yml \
  -e "environment=dev" \
  -e "deploy_api_gateway_only=true"
```

### Step 26: Advanced Usage with Tags

```bash
# Deploy only using specific tags
ansible-playbook playbooks/cf-deployment.yml \
  -t cf-deployment \
  -e "environment=dev"

# Deploy API Gateway with specific tag
ansible-playbook playbooks/cf-deployment.yml \
  -t api-gateway \
  -e "environment=dev" \
  -e "deploy_api_gateway_only=true"

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
  -v
```

### Step 27: Environment Variable Overrides

```bash
# Override API Gateway replicas
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=dev" \
  -e "deploy_api_gateway_only=true" \
  -e "api_gateway_config.replicas=3"

# Override resource limits
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=dev" \
  -e "deploy_api_gateway_only=true" \
  -e "api_gateway_config.resources.limits.cpu=2" \
  -e "api_gateway_config.resources.limits.memory=2Gi"

# Custom environment variables
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=dev" \
  -e "deploy_api_gateway_only=true" \
  -e "api_gateway_config.environment_variables=[{'name': 'SPRING_PROFILES_ACTIVE', 'value': 'dev,custom'}]"
```

---

## Part 10: Verification and Troubleshooting

### Step 28: Verification Commands

```bash
# Check API Gateway deployment status
oc get deployment apigateway-app -n cf-dev

# Check API Gateway pod status
oc get pods -l app=apigateway-app -n cf-dev

# Check API Gateway service
oc get service apigateway-app -n cf-dev

# Check API Gateway route
oc get route apigateway-app -n cf-dev

# Get detailed deployment information
oc describe deployment apigateway-app -n cf-dev

# Check API Gateway logs
oc logs deployment/apigateway-app -n cf-dev --tail=50

# Follow real-time logs
oc logs deployment/apigateway-app -n cf-dev -f

# Check events
oc get events -n cf-dev --sort-by='.lastTimestamp' | grep apigateway

# Test health endpoint
curl -k https://$(oc get route apigateway-app -n cf-dev -o jsonpath='{.spec.host}')/actuator/health

# Check gateway routes
curl -k https://$(oc get route apigateway-app -n cf-dev -o jsonpath='{.spec.host}')/actuator/gateway/routes
```

### Step 29: Advanced Troubleshooting Commands

```bash
# Check Helm release status
helm list -n cf-dev

# Get Helm release details
helm get all cf-microservices-dev -n cf-dev

# Check Helm values
helm get values cf-microservices-dev -n cf-dev

# Check resource usage
oc top pods -l app=apigateway-app -n cf-dev

# Port forward for local testing
oc port-forward deployment/apigateway-app 8765:8765 -n cf-dev

# Exec into pod for debugging
oc exec -it deployment/apigateway-app -n cf-dev -- /bin/bash

# Check service endpoints
oc get endpoints apigateway-app -n cf-dev

# Describe service for detailed info
oc describe service apigateway-app -n cf-dev

# Check network policies (if any)
oc get networkpolicy -n cf-dev

# Check resource quotas
oc get resourcequota -n cf-dev
oc describe resourcequota -n cf-dev
```

### Step 30: Common Issues and Solutions

#### Issue 1: API Gateway Pod Not Starting

```bash
# Check pod status
oc describe pod <pod-name> -n cf-dev

# Common solutions:
# 1. Check resource limits
# 2. Verify image pull secrets
# 3. Check environment variables
# 4. Verify service dependencies

# Fix image pull issues
oc get secret regcred -n cf-dev
oc describe secret regcred -n cf-dev
```

#### Issue 2: Service Discovery Issues

```bash
# Check Eureka registration
curl -k https://$(oc get route apigateway-app -n cf-dev -o jsonpath='{.spec.host}')/actuator/env

# Check DNS resolution
oc exec deployment/apigateway-app -n cf-dev -- nslookup naming-server-new.cf-dev.svc.cluster.local

# Verify service endpoints
oc get endpoints -n cf-dev
```

#### Issue 3: Port Configuration Issues

```bash
# Verify service port configuration
oc get service apigateway-app -n cf-dev -o yaml

# Check if port 8765 is properly configured
oc describe service apigateway-app -n cf-dev

# Test port connectivity
oc exec deployment/apigateway-app -n cf-dev -- netstat -tlnp
```

---

## Part 11: Directory Structure Summary

Your final directory structure should look like this:

```
ansible-project/
├── playbooks/
│   ├── cf-deployment.yml
│   └── api-gateway-deployment.yml
├── roles/
│   └── cf-deployment/
│       ├── defaults/
│       │   └── main.yml
│       ├── tasks/
│       │   ├── main.yml
│       │   ├── validate_prerequisites.yml
│       │   ├── cf-namespace.yml
│       │   ├── cf-microservices.yml
│       │   ├── api-gateway-validations.yml
│       │   └── ecr-token-management.yml
│       ├── vars/
│       │   └── main.yml
│       ├── templates/
│       ├── handlers/
│       ├── meta/
│       │   └── main.yml
│       ├── Doc-deployment/
│       │   └── API-Gateway-Deployment-Guide.md
│       └── execution/
├── helm-charts/
│   └── cf-microservices/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── templates/
│       └── charts/
│           └── api-gateway/
│               ├── Chart.yaml
│               ├── values.yaml
│               └── templates/
│                   ├── deployment.yaml
│                   ├── service.yaml
│                   └── route.yaml
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

This comprehensive guide provides a complete, step-by-step process for creating an Ansible role that deploys API Gateway service using Helm charts on OpenShift/Kubernetes. The implementation includes:

### Key Features:

- **Complete API Gateway Implementation**: Service running on port 8765 with proper configuration
- **Environment Variable Support**: Dynamic configuration through external variables
- **Service Discovery Integration**: Eureka client configuration for microservices architecture
- **Health Checks**: Comprehensive liveness and readiness probes
- **Resource Management**: Proper CPU and memory limits for different environments
- **External Access**: OpenShift routes with TLS termination
- **Validation Framework**: Pre and post deployment validations
- **Troubleshooting Support**: Comprehensive debugging and monitoring capabilities
- **Environment Separation**: Proper dev/test/prod configurations
- **Security**: Security contexts and best practices

### Advanced Capabilities:

- **Rolling Updates**: Zero-downtime deployments
- **Auto-scaling**: Environment-specific scaling policies
- **Monitoring Integration**: Prometheus metrics and Spring Boot Admin integration
- **Dependency Management**: Proper service startup ordering
- **Configuration Management**: External configuration through ConfigMaps and environment variables

This implementation follows industry best practices and provides a production-ready deployment system for API Gateway services in a microservices architecture.