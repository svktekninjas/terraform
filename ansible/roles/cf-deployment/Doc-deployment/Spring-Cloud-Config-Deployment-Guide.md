# Spring Cloud Config Service Deployment Guide
## Complete Step-by-Step Tutorial for Beginners

This comprehensive guide will walk you through creating a complete Ansible role for deploying Spring Cloud Config service using Helm charts on OpenShift/Kubernetes. You'll learn how to create the entire directory structure and write all the code from scratch, exactly as implemented in our current system.

---

## Prerequisites

- Basic understanding of Ansible, Helm, and Kubernetes/OpenShift
- Understanding of Spring Cloud Config Server
- Access to an OpenShift/Kubernetes cluster
- Helm CLI installed (version 3.x)
- OpenShift CLI (oc) installed
- Ansible installed with kubernetes.core collection

---

## Overview

We'll create a complete deployment system including:
1. Ansible role structure for cf-deployment with Spring Cloud Config focus
2. Helm chart specifically for Spring Cloud Config service
3. Environment-specific configurations
4. Centralized configuration management setup
5. Port configuration (8888) and environment variables
6. Deployment automation with monitoring capabilities

---

## Part 1: Understanding Spring Cloud Config Architecture

### Spring Cloud Config Service Details
- **Service Name**: `config-service`
- **Port**: `8888` (standard Spring Cloud Config port)
- **Purpose**: Centralized configuration management for microservices
- **Framework**: Spring Cloud Config Server
- **Container Image**: `spring_cloud_config:latest`

### Key Features We'll Implement
- **Centralized Configuration**: Git-based configuration repository
- **Environment-specific Profiles**: Development, test, production configurations
- **Health Checks**: Kubernetes liveness/readiness probes
- **External Access**: OpenShift routes for configuration API
- **Resource Management**: CPU/Memory limits
- **Dynamic Configuration**: Configuration refresh capabilities
- **Security**: Encrypted configuration properties support

### Service Dependencies
- **Git Repository**: Source of configuration files (optional for standalone mode)
- **Database**: For storing configuration (optional, file-based by default)
- **No Service Dependencies**: Config server is typically the first service to start
- **Client Services**: All microservices depend on this service for configuration

---

## Part 2: Creating the Complete Directory Structure

### Step 1: Create the Root Ansible Project Structure

```bash
# Navigate to your desired project location
cd /path/to/your/project

# Create the main ansible directory
mkdir -p ansible
cd ansible

# Create the complete project structure
mkdir -p {playbooks,roles,environments/{dev,test,prod},helm-charts,inventory}

# Create the complete cf-deployment role structure
mkdir -p roles/cf-deployment/{defaults,tasks,vars,templates,handlers,meta,Doc-deployment,execution}

# Create additional documentation and execution directories
mkdir -p roles/cf-deployment/Doc-deployment
mkdir -p roles/cf-deployment/execution

# Create environment-specific directories
mkdir -p environments/dev
mkdir -p environments/test  
mkdir -p environments/prod

# Create Helm charts structure for microservices
mkdir -p helm-charts/cf-microservices/{charts,templates}
mkdir -p helm-charts/cf-microservices/charts/config-service/{templates,charts}

echo "✅ Directory structure created successfully"
```

### Step 2: Verify the Directory Structure

```bash
# Verify the complete structure
tree ansible/
```

Expected structure:
```
ansible/
├── environments/
│   ├── dev/
│   ├── test/
│   └── prod/
├── helm-charts/
│   └── cf-microservices/
│       ├── charts/
│       │   └── config-service/
│       │       ├── templates/
│       │       └── charts/
│       └── templates/
├── inventory/
├── playbooks/
└── roles/
    └── cf-deployment/
        ├── Doc-deployment/
        ├── defaults/
        ├── execution/
        ├── handlers/
        ├── meta/
        ├── tasks/
        ├── templates/
        └── vars/
```

---

## Part 3: Creating Ansible Role Foundation Files

### Step 3: Create Role Meta Information

Create `roles/cf-deployment/meta/main.yml`:

```yaml
---
galaxy_info:
  author: ConsultingFirm DevOps Team
  description: ConsultingFirm microservices deployment role with Spring Cloud Config support
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
    - spring-cloud-config
    - configuration-management
    - openshift
    - kubernetes
    - helm
    - spring-boot
    - spring-cloud

dependencies:
  - name: kubernetes.core
    version: ">=2.3.0"
```

### Step 4: Create Default Variables

Create `roles/cf-deployment/defaults/main.yml`:

```yaml
---
# Default variables for CF Deployment Role

# Default environment configuration (can be overridden by environment configs)
env: dev
cf_environment: "{{ env | default('dev') }}"
cf_namespace: "cf-{{ env | default('dev') }}"
cf_release_name: "cf-microservices-{{ env | default('dev') }}"

# Helm chart configuration
helm_chart_path: "{{ playbook_dir }}/../helm-charts/cf-microservices"
values_file: "{{ playbook_dir }}/../environments/{{ cf_environment }}/deployment-values.yaml"

# Service deployment flags
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

# Deployment timeouts (in seconds)
helm_timeout: 600
deployment_wait_timeout: 600

# Verification settings
verify_deployment: true
show_deployment_status: true

# ECR Token Management Configuration
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
  timezone: "Asia/Kolkata"
  refresh_interval_hours: 6
  resources:
    limits:
      cpu: "1"
      memory: "2G"
    requests:
      cpu: "500m"
      memory: "1G"

# ECR token management control flags
deploy_ecr_token_management: false
ecr_token_management_enabled: "{{ deploy_ecr_token_management | default(false) }}"
```

### Step 5: Create Role Variables

Create `roles/cf-deployment/vars/main.yml`:

```yaml
---
# Variables for CF Deployment Role

# Environment-specific namespaces
environment_namespaces:
  dev: cf-dev
  test: cf-test
  prod: cf-prod

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

# Service ports mapping
service_ports:
  naming_server: 8761
  api_gateway: 8765
  spring_boot_admin: 8082
  config_service: 8888
  excel_service: 8080
  bench_profile: 8080
  daily_submissions: 8080
  interviews: 8080
  placements: 8080
  frontend: 80

# Environment-specific replica counts
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
    naming_server: 1
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
    naming_server: 2
    api_gateway: 3
    spring_boot_admin: 2
    config_service: 2
    excel_service: 3
    bench_profile: 3
    daily_submissions: 3
    interviews: 3
    placements: 3
    frontend: 4
```

---

## Part 4: Creating Ansible Tasks

### Step 6: Create Main Task File

Create `roles/cf-deployment/tasks/main.yml`:

```yaml
---
# Main tasks file for cf-deployment role

- name: Set default namespace based on environment
  set_fact:
    target_namespace: "{{ environment_namespaces[cf_environment] }}"
  when: target_namespace is not defined

- name: Display deployment configuration
  debug:
    msg:
      - "Environment: {{ cf_environment }}"
      - "Namespace: {{ target_namespace }}"
      - "Release Name: {{ cf_release_name }}"
      - "Helm Chart Path: {{ helm_chart_path }}"

- name: Include ECR token management tasks
  include_tasks: ecr-token-management.yml
  when: ecr_token_management_enabled | bool

- name: Include microservices deployment tasks
  include_tasks: cf-microservices.yml
  tags:
    - cf-deployment
    - microservices
    - config-service
    - spring-cloud-config
```

### Step 7: Create Microservices Deployment Tasks

Create `roles/cf-deployment/tasks/cf-microservices.yml`:

```yaml
---
# CF Microservices deployment tasks

- name: Ensure target namespace exists
  kubernetes.core.k8s:
    name: "{{ target_namespace }}"
    api_version: v1
    kind: Namespace
    state: present
  tags:
    - namespace
    - cf-deployment

- name: Check if Helm release exists
  kubernetes.core.helm_info:
    name: "{{ cf_release_name }}"
    namespace: "{{ target_namespace }}"
  register: helm_release_info
  ignore_errors: true
  tags:
    - helm
    - cf-deployment

- name: Display Helm release status
  debug:
    msg: "Helm release {{ cf_release_name }} status: {{ helm_release_info.status.status if helm_release_info.status is defined else 'Not found' }}"
  tags:
    - helm
    - cf-deployment

- name: Deploy CF microservices using Helm (Config Service Only)
  kubernetes.core.helm:
    name: "{{ cf_release_name }}"
    chart_ref: "{{ helm_chart_path }}"
    namespace: "{{ target_namespace }}"
    create_namespace: true
    values:
      global:
        namespace: "{{ target_namespace }}"
        registry: "{{ ecr_registry }}"
        imagePullSecrets:
          - name: ecr-secret
      # Enable only Config Service
      configService:
        enabled: true
      namingServer:
        enabled: false
      apiGateway:
        enabled: false
      springBootAdmin:
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
      # Config Service specific configuration
      config-service:
        image:
          repository: spring_cloud_config
          tag: latest
        service:
          port: 8888
        deployment:
          replicas: "{{ replica_counts[cf_environment]['config_service'] }}"
          env: "{{ config_service_env_vars | default([]) }}"
        route:
          enabled: true
          tls:
            termination: edge
    wait: true
    wait_condition:
      type: Progressing
      status: "True"
      reason: NewReplicaSetAvailable
    wait_timeout: "{{ helm_timeout }}"
  when: deploy_config_service_only | default(false)
  tags:
    - helm
    - cf-deployment
    - config-service

- name: Deploy CF microservices using Helm (All Services)
  kubernetes.core.helm:
    name: "{{ cf_release_name }}"
    chart_ref: "{{ helm_chart_path }}"
    namespace: "{{ target_namespace }}"
    create_namespace: true
    values_files:
      - "{{ values_file }}"
    wait: true
    wait_condition:
      type: Progressing
      status: "True"
      reason: NewReplicaSetAvailable
    wait_timeout: "{{ helm_timeout }}"
  when: not (deploy_config_service_only | default(false))
  tags:
    - helm
    - cf-deployment

- name: Wait for Config Service deployment to be ready
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    name: config-service
    namespace: "{{ target_namespace }}"
    wait: true
    wait_condition:
      type: Progressing
      status: "True"
      reason: NewReplicaSetAvailable
    wait_timeout: "{{ deployment_wait_timeout }}"
  when: verify_deployment | bool
  tags:
    - verification
    - config-service

- name: Get Config Service deployment status
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    name: config-service
    namespace: "{{ target_namespace }}"
  register: config_service_deployment
  when: show_deployment_status | bool
  tags:
    - status
    - config-service

- name: Display Config Service deployment status
  debug:
    msg:
      - "Config Service Deployment Status:"
      - "Ready Replicas: {{ config_service_deployment.resources[0].status.readyReplicas | default(0) }}"
      - "Available Replicas: {{ config_service_deployment.resources[0].status.availableReplicas | default(0) }}"
      - "Updated Replicas: {{ config_service_deployment.resources[0].status.updatedReplicas | default(0) }}"
  when: 
    - show_deployment_status | bool
    - config_service_deployment.resources is defined
    - config_service_deployment.resources | length > 0
  tags:
    - status
    - config-service
```

### Step 8: Create ECR Token Management Tasks

Create `roles/cf-deployment/tasks/ecr-token-management.yml`:

```yaml
---
# ECR Token Management tasks

- name: Create ECR credentials sync service account
  kubernetes.core.k8s:
    name: "{{ ecr_token_config.service_account_name }}"
    api_version: v1
    kind: ServiceAccount
    namespace: "{{ target_namespace }}"
    definition:
      metadata:
        annotations:
          eks.amazonaws.com/role-arn: "{{ ecr_token_config.iam_role_arn }}"
    state: present
  tags:
    - ecr
    - serviceaccount

- name: Create RBAC role for ECR secret management
  kubernetes.core.k8s:
    name: "{{ ecr_token_config.rbac_role_name }}"
    api_version: rbac.authorization.k8s.io/v1
    kind: Role
    namespace: "{{ target_namespace }}"
    definition:
      rules:
        - apiGroups: [""]
          resources: ["secrets"]
          verbs: ["get", "list", "create", "update", "patch", "delete"]
    state: present
  tags:
    - ecr
    - rbac

- name: Create RBAC role binding for ECR credentials sync
  kubernetes.core.k8s:
    name: "{{ ecr_token_config.rbac_binding_name }}"
    api_version: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    namespace: "{{ target_namespace }}"
    definition:
      subjects:
        - kind: ServiceAccount
          name: "{{ ecr_token_config.service_account_name }}"
          namespace: "{{ target_namespace }}"
      roleRef:
        kind: Role
        name: "{{ ecr_token_config.rbac_role_name }}"
        apiGroup: rbac.authorization.k8s.io
    state: present
  tags:
    - ecr
    - rbac
```

---

## Part 5: Creating Helm Chart Structure

### Step 9: Create Main Helm Chart Files

Create `helm-charts/cf-microservices/Chart.yaml`:

```yaml
apiVersion: v2
name: cf-microservices
description: A Helm chart for ConsultingFirm microservices including Spring Cloud Config
type: application
version: 0.1.0
appVersion: "1.0.0"
maintainers:
  - name: ConsultingFirm DevOps Team
    email: devops@consultingfirm.com
keywords:
  - microservices
  - spring-boot
  - spring-cloud
  - spring-cloud-config
  - configuration-management
sources:
  - https://github.com/consultingfirm/microservices
dependencies: []
```

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

### Step 10: Create Config Service Specific Helm Chart

Create `helm-charts/cf-microservices/charts/config-service/Chart.yaml`:

```yaml
apiVersion: v2
name: config-service
description: Spring Cloud Config Server Helm chart
type: application
version: 0.1.0
appVersion: "1.0.0"
maintainers:
  - name: ConsultingFirm DevOps Team
    email: devops@consultingfirm.com
keywords:
  - spring-cloud-config
  - configuration-management
  - microservices
  - spring-boot
```

Create `helm-charts/cf-microservices/charts/config-service/values.yaml`:

```yaml
image:
  repository: spring_cloud_config
  tag: latest
  pullPolicy: Always

service:
  type: ClusterIP
  port: 8888
  targetPort: 8888

deployment:
  replicas: 1
  env:
    - name: SERVER_PORT
      value: "8888"
    - name: SPRING_PROFILES_ACTIVE
      value: "native"
    - name: SPRING_CLOUD_CONFIG_SERVER_NATIVE_SEARCH_LOCATIONS
      value: "classpath:/config/"
    - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
      value: "health,info,metrics,env,configprops"
    - name: MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS
      value: "always"
    - name: LOGGING_LEVEL_ROOT
      value: "INFO"
    - name: LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_CLOUD_CONFIG
      value: "DEBUG"
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 256Mi

route:
  enabled: true
  host: ""
  tls:
    termination: edge

global:
  namespace: cf-dev
  registry: 818140567777.dkr.ecr.us-east-1.amazonaws.com/consultingfirm
  imagePullSecrets:
    - name: ecr-secret
```

### Step 11: Create Config Service Deployment Template

Create `helm-charts/cf-microservices/charts/config-service/templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-service
  namespace: {{ .Values.global.namespace }}
  labels:
    app: config-service
    version: {{ .Chart.AppVersion }}
spec:
  replicas: {{ .Values.deployment.replicas }}
  selector:
    matchLabels:
      app: config-service
  template:
    metadata:
      labels:
        app: config-service
        version: {{ .Chart.AppVersion }}
    spec:
      {{- if .Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml .Values.global.imagePullSecrets | nindent 8 }}
      {{- end }}
      containers:
      - name: config-service
        image: "{{ .Values.global.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
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
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: {{ .Values.service.targetPort }}
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: {{ .Values.service.targetPort }}
          initialDelaySeconds: 30
          periodSeconds: 10
```

### Step 12: Create Config Service Service Template

Create `helm-charts/cf-microservices/charts/config-service/templates/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: config-service
  namespace: {{ .Values.global.namespace }}
  labels:
    app: config-service
    version: {{ .Chart.AppVersion }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
      protocol: TCP
      name: http
  selector:
    app: config-service
```

### Step 13: Create Config Service Route Template

Create `helm-charts/cf-microservices/charts/config-service/templates/route.yaml`:

```yaml
{{- if .Values.route.enabled }}
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: config-service
  namespace: {{ .Values.global.namespace }}
  labels:
    app: config-service
    version: {{ .Chart.AppVersion }}
spec:
  {{- if .Values.route.host }}
  host: {{ .Values.route.host }}
  {{- end }}
  to:
    kind: Service
    name: config-service
    weight: 100
  port:
    targetPort: http
  {{- if .Values.route.tls }}
  tls:
    termination: {{ .Values.route.tls.termination }}
    {{- if .Values.route.tls.insecureEdgeTerminationPolicy }}
    insecureEdgeTerminationPolicy: {{ .Values.route.tls.insecureEdgeTerminationPolicy }}
    {{- end }}
  {{- end }}
  wildcardPolicy: None
{{- end }}
```

---

## Part 6: Creating Environment-Specific Configurations

### Step 14: Create Development Environment Configuration

Create `environments/dev/deployment-values.yaml`:

```yaml
# Development Environment Configuration for CF Microservices

global:
  namespace: cf-dev
  registry: 818140567777.dkr.ecr.us-east-1.amazonaws.com/consultingfirm
  pullPolicy: Always
  imagePullSecrets:
    - name: ecr-secret

# Service enablement for development
configService:
  enabled: true

# Config Service specific configuration for development
config-service:
  image:
    repository: spring_cloud_config
    tag: latest
  service:
    port: 8888
  deployment:
    replicas: 1
    env:
      - name: SERVER_PORT
        value: "8888"
      - name: SPRING_PROFILES_ACTIVE
        value: "native,dev"
      - name: SPRING_CLOUD_CONFIG_SERVER_NATIVE_SEARCH_LOCATIONS
        value: "classpath:/config/"
      - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
        value: "health,info,metrics,env,configprops,refresh"
      - name: MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS
        value: "always"
      - name: LOGGING_LEVEL_ROOT
        value: "INFO"
      - name: LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_CLOUD_CONFIG
        value: "DEBUG"
      - name: SPRING_CLOUD_CONFIG_SERVER_HEALTH_ENABLED
        value: "true"
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 200m
        memory: 256Mi
  route:
    enabled: true
    tls:
      termination: edge
```

Create `environments/dev/cf-deployment.yml`:

```yaml
---
# CF Deployment Configuration for DEV Environment

# Environment configuration
env: dev
cf_environment: dev
cf_namespace: cf-dev
cf_release_name: cf-microservices-dev

# Helm chart configuration
helm_chart_path: "{{ playbook_dir }}/helm-charts/cf-microservices"
values_file: "{{ playbook_dir }}/environments/dev/deployment-values.yaml"

# Service deployment flags for dev (enable all services by default)
deploy_naming_server_only: false
deploy_api_gateway_only: false
deploy_spring_boot_admin_only: false
deploy_config_service_only: false
deploy_business_services_only: false
deploy_frontend_only: false

# Deployment settings for dev
deployment_timeout: 600
verify_deployment: true
show_deployment_status: true

# Resource limits for dev (lighter resources)
dev_resource_limits:
  cpu: "500m"
  memory: "512Mi"
dev_resource_requests:
  cpu: "100m"
  memory: "256Mi"

# Replica counts for dev (minimal replicas)
replica_config:
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

# Dev-specific labels
environment_labels:
  environment: dev
  purpose: development
  team: consultingfirm
```

---

## Part 7: Creating the Main Playbook

### Step 15: Create Main Playbook

Create `playbooks/main.yml`:

```yaml
---
- name: Deploy ConsultingFirm Microservices
  hosts: localhost
  connection: local
  gather_facts: false
  
  vars:
    # Default environment (can be overridden)
    environment: "{{ env | default('dev') }}"
    
  tasks:
    - name: Set environment-specific variables
      include_vars: "{{ playbook_dir }}/../environments/{{ environment }}/cf-deployment.yml"
      tags:
        - always

    - name: Display deployment information
      debug:
        msg:
          - "Deploying ConsultingFirm microservices"
          - "Environment: {{ cf_environment }}"
          - "Namespace: {{ cf_namespace }}"
          - "Release: {{ cf_release_name }}"
      tags:
        - always

    - name: Deploy microservices using cf-deployment role
      include_role:
        name: cf-deployment
      vars:
        cf_environment: "{{ environment }}"
        target_namespace: "{{ cf_namespace }}"
      tags:
        - cf-deployment
        - microservices
        - config-service
```

---

## Part 8: Spring Cloud Config Specific Configuration

### Step 16: Advanced Config Service Environment Variables

When deploying Spring Cloud Config with external Git repository, use these environment variables in your deployment:

```yaml
# For Git-based configuration (add to deployment-values.yaml)
config-service:
  deployment:
    env:
      - name: SERVER_PORT
        value: "8888"
      - name: SPRING_PROFILES_ACTIVE
        value: "git"
      - name: SPRING_CLOUD_CONFIG_SERVER_GIT_URI
        value: "https://github.com/your-org/config-repo.git"
      - name: SPRING_CLOUD_CONFIG_SERVER_GIT_DEFAULT_LABEL
        value: "main"
      - name: SPRING_CLOUD_CONFIG_SERVER_GIT_SEARCH_PATHS
        value: "config/{application}"
      - name: SPRING_CLOUD_CONFIG_SERVER_GIT_CLONE_ON_START
        value: "true"
      - name: SPRING_CLOUD_CONFIG_SERVER_GIT_USERNAME
        value: "your-git-username"
      - name: SPRING_CLOUD_CONFIG_SERVER_GIT_PASSWORD
        value: "your-git-token"
      - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
        value: "health,info,metrics,env,configprops,refresh,bus-refresh"
      - name: MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS
        value: "always"
      - name: SPRING_CLOUD_CONFIG_SERVER_HEALTH_ENABLED
        value: "true"
```

### Step 17: Configuration Repository Structure

For external Git-based configuration, create this repository structure:

```
config-repo/
├── application.yml                 # Global configuration for all services
├── application-dev.yml            # Global dev environment config
├── application-test.yml           # Global test environment config
├── application-prod.yml           # Global prod environment config
├── config/
│   ├── api-gateway/
│   │   ├── api-gateway.yml        # API Gateway specific config
│   │   ├── api-gateway-dev.yml    # API Gateway dev config
│   │   └── api-gateway-prod.yml   # API Gateway prod config
│   ├── naming-server/
│   │   ├── naming-server.yml      # Naming Server specific config
│   │   └── naming-server-dev.yml  # Naming Server dev config
│   ├── spring-boot-admin/
│   │   └── spring-boot-admin.yml  # Spring Boot Admin config
│   └── business-services/
│       ├── excel-service.yml      # Excel Service config
│       ├── interviews-service.yml # Interviews Service config
│       └── placements-service.yml # Placements Service config
└── README.md
```

---

## Part 9: Deployment Execution Instructions

### Step 18: Deploy Config Service Only

```bash
# Navigate to ansible directory
cd ansible

# Deploy only Config Service
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_config_service_only=true" \
  -e "environment=dev"
```

### Step 19: Deploy with Custom Environment Variables

```bash
# Deploy Config Service with custom configuration
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_config_service_only=true" \
  -e "environment=dev" \
  -e "config_service_env_vars=[
    {'name': 'SERVER_PORT', 'value': '8888'},
    {'name': 'SPRING_PROFILES_ACTIVE', 'value': 'native,dev'},
    {'name': 'SPRING_CLOUD_CONFIG_SERVER_NATIVE_SEARCH_LOCATIONS', 'value': 'classpath:/config/'},
    {'name': 'MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE', 'value': 'health,info,metrics,env,configprops,refresh'},
    {'name': 'LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_CLOUD_CONFIG', 'value': 'DEBUG'}
  ]"
```

### Step 20: Deploy All Services

```bash
# Deploy all microservices including Config Service
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "environment=dev"
```

---

## Part 10: Verification and Testing

### Step 21: Verify Deployment

```bash
# Check Helm release
helm list -n cf-dev

# Check deployment status
oc get deployment config-service -n cf-dev

# Check pod status
oc get pods -l app=config-service -n cf-dev

# Check service
oc get svc config-service -n cf-dev

# Check route
oc get route config-service -n cf-dev
```

### Step 22: Test Config Service Functionality

```bash
# Get Config Service URL
CONFIG_URL="https://$(oc get route config-service -n cf-dev -o jsonpath='{.spec.host}')"

# Test health endpoint
curl -k "$CONFIG_URL/actuator/health"

# Test info endpoint
curl -k "$CONFIG_URL/actuator/info"

# Test configuration endpoints (for application named 'test-app')
curl -k "$CONFIG_URL/test-app/default"
curl -k "$CONFIG_URL/test-app/dev"

# Test refresh endpoint (POST)
curl -k -X POST "$CONFIG_URL/actuator/refresh"
```

---

## Part 11: Advanced Configuration Management

### Step 23: Configuration Encryption (Optional)

To encrypt sensitive configuration values, add these environment variables:

```yaml
config-service:
  deployment:
    env:
      - name: ENCRYPT_KEY
        value: "your-encryption-key-here"
      - name: SPRING_CLOUD_CONFIG_SERVER_ENCRYPT_ENABLED
        value: "true"
```

### Step 24: Database Backend Configuration (Optional)

For database-backed configuration:

```yaml
config-service:
  deployment:
    env:
      - name: SPRING_PROFILES_ACTIVE
        value: "jdbc"
      - name: SPRING_DATASOURCE_URL
        value: "jdbc:postgresql://postgres:5432/configdb"
      - name: SPRING_DATASOURCE_USERNAME
        value: "configuser"
      - name: SPRING_DATASOURCE_PASSWORD
        value: "configpassword"
      - name: SPRING_CLOUD_CONFIG_SERVER_JDBC_SQL
        value: "SELECT KEY, VALUE from PROPERTIES where APPLICATION=? and PROFILE=? and LABEL=?"
```

---

## Part 12: Monitoring and Observability

### Step 25: Add Monitoring Configuration

```yaml
config-service:
  deployment:
    env:
      - name: MANAGEMENT_METRICS_EXPORT_PROMETHEUS_ENABLED
        value: "true"
      - name: MANAGEMENT_ENDPOINT_PROMETHEUS_ENABLED
        value: "true"
      - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
        value: "health,info,metrics,env,configprops,refresh,prometheus"
```

### Step 26: Health Check Configuration

```yaml
config-service:
  deployment:
    env:
      - name: MANAGEMENT_HEALTH_DISKSPACE_ENABLED
        value: "true"
      - name: MANAGEMENT_HEALTH_PING_ENABLED
        value: "true"
      - name: MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS
        value: "always"
      - name: MANAGEMENT_ENDPOINT_HEALTH_SHOW_COMPONENTS
        value: "always"
```

---

## Part 13: Troubleshooting Guide

### Common Issues and Solutions

1. **Config Service Not Starting**
   ```bash
   # Check pod logs
   oc logs deployment/config-service -n cf-dev
   
   # Check events
   oc get events -n cf-dev --field-selector involvedObject.name=config-service
   ```

2. **Configuration Not Loading**
   ```bash
   # Test configuration endpoint
   curl -k "$CONFIG_URL/application/default"
   
   # Check configuration paths
   oc exec deployment/config-service -n cf-dev -- ls -la /config/
   ```

3. **Service Connection Issues**
   ```bash
   # Test internal connectivity
   oc run test-pod --image=curlimages/curl -it --rm -- curl http://config-service:8888/actuator/health
   ```

---

## Part 14: Cleanup and Maintenance

### Step 27: Update Configuration

```bash
# Update configuration and restart
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_config_service_only=true" \
  -e "environment=dev" \
  -e "config_service_env_vars=[{'name': 'LOGGING_LEVEL_ROOT', 'value': 'DEBUG'}]"
```

### Step 28: Scale Configuration Service

```bash
# Scale up for high availability
helm upgrade cf-microservices-dev helm-charts/cf-microservices \
  -n cf-dev \
  --set config-service.deployment.replicas=2
```

### Step 29: Cleanup

```bash
# Remove Config Service only
oc delete deployment config-service -n cf-dev
oc delete service config-service -n cf-dev
oc delete route config-service -n cf-dev

# Remove entire release
helm uninstall cf-microservices-dev -n cf-dev
```

---

## Success Criteria Checklist

- [ ] Complete directory structure created
- [ ] All Ansible role files properly configured
- [ ] Helm chart created with correct templates
- [ ] Environment-specific configurations set up
- [ ] Config Service deploys successfully
- [ ] Service accessible on port 8888
- [ ] Health endpoints responding correctly
- [ ] Configuration endpoints functional
- [ ] Routes properly configured
- [ ] Environment variables set correctly
- [ ] Resource limits applied
- [ ] Monitoring endpoints enabled

---

## Conclusion

This comprehensive guide provides everything needed to create a complete Spring Cloud Config service deployment from scratch. The modular structure allows for easy maintenance and scaling, while the environment-specific configurations ensure proper separation between development, test, and production environments.

For additional features like configuration encryption, database backends, or advanced monitoring, refer to the Spring Cloud Config documentation and extend the configurations accordingly.

---

## Contact & Support

For issues or questions:
- Check Spring Cloud Config documentation
- Review application logs: `oc logs deployment/config-service -n cf-dev`
- Test configuration endpoints manually
- Contact DevOps team for infrastructure issues