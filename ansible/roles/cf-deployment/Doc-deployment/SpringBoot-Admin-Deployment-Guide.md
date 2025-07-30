# Spring Boot Admin Service Deployment Guide
## Complete Step-by-Step Tutorial for Beginners

This guide will walk you through creating a complete Ansible role for deploying Spring Boot Admin service using Helm charts on OpenShift/Kubernetes. You'll learn how to create the entire directory structure and write all the code from scratch.

## Prerequisites

- Basic understanding of Ansible, Helm, and Kubernetes/OpenShift
- Access to an OpenShift/Kubernetes cluster
- Helm CLI installed
- OpenShift CLI (oc) installed

## Overview

We'll create:
1. Ansible role structure for cf-deployment
2. Helm chart for Spring Boot Admin service
3. Environment-specific configurations
4. Deployment automation

---

## Part 1: Creating the Ansible Role Structure

### Step 1: Create the Base Role Directory

```bash
# Navigate to your ansible project root
cd /path/to/your/ansible/project

# Create the cf-deployment role structure
mkdir -p roles/cf-deployment/{defaults,tasks,vars,templates,handlers,meta}
```

### Step 2: Create Role Meta Information

Create `roles/cf-deployment/meta/main.yml`:

```yaml
---
galaxy_info:
  author: DevOps Team
  description: ConsultingFirm microservices deployment role
  company: ConsultingFirm
  license: MIT
  min_ansible_version: 2.9
  platforms:
    - name: EL
      versions:
        - 8
        - 9
  galaxy_tags:
    - deployment
    - microservices
    - openshift
    - kubernetes
    - helm

dependencies: []
```

### Step 3: Create Default Variables

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

# Service deployment flags - Control which services to deploy
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

### Step 4: Create Role Variables

Create `roles/cf-deployment/vars/main.yml`:

```yaml
---
# Internal variables for CF Deployment Role

# Supported environments
supported_environments:
  - dev
  - test
  - prod

# Service port mappings
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

# Default resource configurations
default_resources:
  small:
    limits:
      cpu: "500m"
      memory: "512Mi"
    requests:
      cpu: "200m"
      memory: "256Mi"
  medium:
    limits:
      cpu: "1"
      memory: "1Gi"
    requests:
      cpu: "500m"
      memory: "512Mi"
  large:
    limits:
      cpu: "2"
      memory: "2Gi"
    requests:
      cpu: "1"
      memory: "1Gi"
```

---

## Part 2: Creating the Main Tasks

### Step 5: Create Main Task File

Create `roles/cf-deployment/tasks/main.yml`:

```yaml
---
# CF Deployment Role - Main Tasks
# Deploy ConsultingFirm microservices using Helm charts

- name: CF Deployment - Start orchestration
  debug:
    msg:
      - "Starting CF Deployment orchestration"
      - "Environment: {{ cf_environment }}"
      - "Namespace: {{ cf_namespace }}"
      - "Release: {{ cf_release_name }}"
  tags:
    - cf-deployment
    - deployment
    - microservices
    - orchestration

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

- name: CF Deployment - Orchestration completed
  debug:
    msg:
      - "CF Deployment orchestration completed successfully"
      - "Environment: {{ cf_environment }}"
      - "Namespace: {{ cf_namespace }}"
      - "Release: {{ cf_release_name }}"
  tags:
    - cf-deployment
    - complete
    - deployment
    - microservices
    - orchestration
```

### Step 6: Create Namespace Task File

Create `roles/cf-deployment/tasks/cf-namespace.yml`:

```yaml
---
# CF Deployment Role - Namespace Management
# Create and manage the CF namespace

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
  tags:
    - cf-deployment
    - cf-namespace
    - namespace
    - verify

- name: Namespace creation completed
  debug:
    msg: "Namespace {{ cf_namespace }} is ready for deployments"
  tags:
    - cf-deployment
    - cf-namespace
    - namespace
    - complete
```

### Step 7: Create ECR Token Management Task

Create `roles/cf-deployment/tasks/ecr-token-management.yml`:

```yaml
---
# CF Deployment Role - ECR Token Management
# Deploy ECR credentials synchronization service

- name: ECR Token Management - Start deployment
  debug:
    msg:
      - "Starting ECR Token Management deployment"
      - "Namespace: {{ cf_namespace }}"
      - "ECR Registry: {{ ecr_token_config.ecr_registry }}"
  tags:
    - cf-deployment
    - ecr-token-management
    - continuous-auth

- name: Deploy ECR Token Management using Helm
  kubernetes.core.helm:
    name: "{{ ecr_token_config.deployment_name }}"
    chart_ref: "{{ helm_chart_path }}/charts/ecr-token-management"
    release_namespace: "{{ cf_namespace }}"
    create_namespace: false
    values:
      global:
        namespace: "{{ cf_namespace }}"
      ecr_token_config: "{{ ecr_token_config }}"
    state: present
    wait: true
    wait_timeout: "{{ helm_timeout }}s"
  tags:
    - cf-deployment
    - ecr-token-management
    - continuous-auth
    - helm-deploy

- name: ECR Token Management - Deployment completed
  debug:
    msg: "ECR Token Management deployed successfully in {{ cf_namespace }}"
  tags:
    - cf-deployment
    - ecr-token-management
    - continuous-auth
    - complete
```

---

## Part 3: Creating the Core Microservices Deployment

### Step 8: Create Microservices Deployment Task

Create `roles/cf-deployment/tasks/cf-microservices.yml`:

```yaml
---
# CF Deployment Role - Helm Integration
# Deploy ConsultingFirm microservices using Helm charts

- name: Deploy CF Microservices using Helm
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
    state: present
    wait: true
    wait_timeout: 600s
    force: true
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
    wait_timeout: 600
  register: deployments_status
  tags:
    - cf-deployment
    - deployment
    - cf-verify
    - verify

- name: Display deployment status
  debug:
    msg: "Found {{ deployments_status.resources | length }} deployments in {{ cf_namespace }} namespace"
  tags:
    - cf-deployment
    - deployment
    - cf-verify
    - verify

# Individual service deployment tasks with specific tags
- name: Deploy Spring Boot Admin only
  kubernetes.core.helm:
    name: "{{ cf_release_name | default('cf-microservices') }}"
    chart_ref: "{{ chart_path | default(playbook_dir + '/../helm-charts/cf-microservices') }}"
    release_namespace: "{{ cf_namespace }}"
    create_namespace: false
    values_files:
      - "{{ values_file }}"
    values:
      global:
        namespace: "{{ cf_namespace }}"
      namingServer:
        enabled: false
      apiGateway:
        enabled: false
      springBootAdmin:
        enabled: true
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
    state: present
    wait: true
    wait_timeout: 300s
  when: deploy_spring_boot_admin_only | default(false)
  tags:
    - cf-deployment
    - deployment
    - cf-spring-boot-admin
    - spring-boot-admin
```

---

## Part 4: Creating the Helm Chart Structure

### Step 9: Create Main Helm Chart Structure

```bash
# Navigate to your project root
cd /path/to/your/ansible/project

# Create the main helm chart structure
mkdir -p helm-charts/cf-microservices/{charts,templates}
mkdir -p helm-charts/cf-microservices/charts/spring-boot-admin/{templates,charts}
```

### Step 10: Create Main Helm Chart Configuration

Create `helm-charts/cf-microservices/Chart.yaml`:

```yaml
apiVersion: v2
name: cf-microservices
description: ConsultingFirm Microservices Helm Chart
type: application
version: 1.0.0
appVersion: "1.0.0"
keywords:
  - microservices
  - spring-boot
  - consulting-firm
home: https://consultingfirm.com
sources:
  - https://github.com/consultingfirm/microservices
maintainers:
  - name: DevOps Team
    email: devops@consultingfirm.com
dependencies:
  - name: spring-boot-admin
    version: "1.0.0"
    repository: "file://charts/spring-boot-admin"
    condition: springBootAdmin.enabled
```

### Step 11: Create Main Helm Values File

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
```

---

## Part 5: Creating Spring Boot Admin Specific Helm Chart

### Step 12: Create Spring Boot Admin Chart Configuration

Create `helm-charts/cf-microservices/charts/spring-boot-admin/Chart.yaml`:

```yaml
apiVersion: v2
name: spring-boot-admin
description: Spring Boot Admin Service Helm Chart
type: application
version: 1.0.0
appVersion: "2.7.0"
keywords:
  - spring-boot
  - admin
  - monitoring
  - microservices
home: https://github.com/codecentric/spring-boot-admin
sources:
  - https://github.com/codecentric/spring-boot-admin
maintainers:
  - name: DevOps Team
    email: devops@consultingfirm.com
```

### Step 13: Create Spring Boot Admin Values

Create `helm-charts/cf-microservices/charts/spring-boot-admin/values.yaml`:

```yaml
image:
  repository: spring-boot-admin
  tag: latest
  pullPolicy: Always

service:
  type: ClusterIP
  port: 8082
  targetPort: 8082

deployment:
  replicas: 1
  env:
    - name: SPRING_PROFILES_ACTIVE
      value: "openshift"
    - name: SERVER_PORT
      value: "8082"
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
```

### Step 14: Create Spring Boot Admin Deployment Template

Create `helm-charts/cf-microservices/charts/spring-boot-admin/templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-boot-admin
  namespace: {{ .Values.global.namespace }}
  labels:
    app: spring-boot-admin
    version: {{ .Chart.AppVersion }}
spec:
  replicas: {{ .Values.deployment.replicas }}
  selector:
    matchLabels:
      app: spring-boot-admin
  template:
    metadata:
      labels:
        app: spring-boot-admin
        version: {{ .Chart.AppVersion }}
    spec:
#      serviceAccountName: {{ .Values.global.serviceAccount }}
      {{- if .Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml .Values.global.imagePullSecrets | nindent 8 }}
      {{- end }}
      containers:
      - name: spring-boot-admin
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

### Step 15: Create Spring Boot Admin Service Template

Create `helm-charts/cf-microservices/charts/spring-boot-admin/templates/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: spring-boot-admin
  namespace: {{ .Values.global.namespace }}
  labels:
    app: spring-boot-admin
    version: {{ .Chart.AppVersion }}
spec:
  type: {{ .Values.service.type }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: {{ .Values.service.targetPort }}
    protocol: TCP
    name: http
  selector:
    app: spring-boot-admin
```

### Step 16: Create Spring Boot Admin Route Template

Create `helm-charts/cf-microservices/charts/spring-boot-admin/templates/route.yaml`:

```yaml
{{- if .Values.route.enabled }}
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: spring-boot-admin
  namespace: {{ .Values.global.namespace }}
  labels:
    app: spring-boot-admin
    version: {{ .Chart.AppVersion }}
spec:
  {{- if .Values.route.host }}
  host: {{ .Values.route.host }}
  {{- end }}
  to:
    kind: Service
    name: spring-boot-admin
    weight: 100
  port:
    targetPort: http
  {{- if .Values.route.tls }}
  tls:
    termination: {{ .Values.route.tls.termination }}
  {{- end }}
  wildcardPolicy: None
{{- end }}
```

---

## Part 6: Creating Environment-Specific Configurations

### Step 17: Create Environment Directory Structure

```bash
# Create environment directories
mkdir -p environments/{dev,test,prod}
```

### Step 18: Create Development Environment Configuration

Create `environments/dev/dev.yml`:

```yaml
# Development Environment Variables for CF Deployment
---
environment_name: "dev"

# AWS Region Configuration
aws_region: "us-east-1"

# Cluster Configuration
cluster_name: "rosa-cluster"
openshift_version: "4.14"
instance_type: "m5.large"

# Autoscaling Configuration
enable_autoscaling: true
min_replicas: 2
max_replicas: 5

# Validation Toggles
strict_validation: false
fail_fast: true

# Logging and Debug
enable_debug_logging: true
log_validation_results: true
```

### Step 19: Create Development Deployment Values

Create `environments/dev/deployment-values.yaml`:

```yaml
# Development Environment Values
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

api-gateway:
  deployment:
    replicas: 1
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

# ECR token management control (can be overridden via command line)
deploy_ecr_token_management: false
```

---

## Part 7: Creating the Main Playbook

### Step 20: Create Main Playbook

Create `playbooks/cf-deployment.yml`:

```yaml
---
- name: CF Microservices Deployment
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
          - "===================================="

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
          - "=============================="
```

---

## Part 8: Usage Examples

### Step 21: Basic Usage Commands

```bash
# Deploy all services to dev environment
ansible-playbook playbooks/cf-deployment.yml -e "environment=dev"

# Deploy only Spring Boot Admin service
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=dev" \
  -e "deploy_spring_boot_admin_only=true"

# Deploy to production environment
ansible-playbook playbooks/cf-deployment.yml -e "environment=prod"

# Deploy with ECR token management enabled
ansible-playbook playbooks/cf-deployment.yml \
  -e "environment=dev" \
  -e "deploy_ecr_token_management=true"
```

### Step 22: Advanced Usage with Tags

```bash
# Deploy only using specific tags
ansible-playbook playbooks/cf-deployment.yml -t cf-deployment -e "environment=dev"

# Deploy Spring Boot Admin with specific tag
ansible-playbook playbooks/cf-deployment.yml \
  -t spring-boot-admin \
  -e "environment=dev" \
  -e "deploy_spring_boot_admin_only=true"

# Skip certain tasks
ansible-playbook playbooks/cf-deployment.yml \
  --skip-tags ecr-token-management \
  -e "environment=dev"
```

---

## Part 9: Verification and Troubleshooting

### Step 23: Verification Commands

```bash
# Check deployment status
oc get deployments -n cf-dev

# Check pod status
oc get pods -n cf-dev

# Check service status
oc get services -n cf-dev

# Check routes
oc get routes -n cf-dev

# Check Spring Boot Admin specifically
oc get deployment spring-boot-admin -n cf-dev
oc get service spring-boot-admin -n cf-dev
oc get route spring-boot-admin -n cf-dev

# Check logs
oc logs deployment/spring-boot-admin -n cf-dev
```

### Step 24: Common Troubleshooting

```bash
# Check Helm release status
helm list -n cf-dev

# Get Helm release details
helm get all cf-microservices-dev -n cf-dev

# Check Helm values
helm get values cf-microservices-dev -n cf-dev

# Rollback if needed
helm rollback cf-microservices-dev -n cf-dev

# Force recreate pods
oc delete pod -l app=spring-boot-admin -n cf-dev
```

---

## Part 10: Directory Structure Summary

Your final directory structure should look like this:

```
ansible-project/
├── playbooks/
│   └── cf-deployment.yml
├── roles/
│   └── cf-deployment/
│       ├── defaults/
│       │   └── main.yml
│       ├── tasks/
│       │   ├── main.yml
│       │   ├── cf-namespace.yml
│       │   ├── cf-microservices.yml
│       │   └── ecr-token-management.yml
│       ├── vars/
│       │   └── main.yml
│       ├── templates/
│       ├── handlers/
│       └── meta/
│           └── main.yml
├── helm-charts/
│   └── cf-microservices/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── templates/
│       └── charts/
│           └── spring-boot-admin/
│               ├── Chart.yaml
│               ├── values.yaml
│               └── templates/
│                   ├── deployment.yaml
│                   ├── service.yaml
│                   └── route.yaml
└── environments/
    ├── dev/
    │   ├── dev.yml
    │   └── deployment-values.yaml
    ├── test/
    │   ├── test.yml
    │   └── deployment-values.yaml
    └── prod/
        ├── prod.yml
        └── deployment-values.yaml
```

---

## Conclusion

This guide provides a complete, step-by-step process for creating an Ansible role that deploys Spring Boot Admin service using Helm charts. The structure is modular, reusable, and follows best practices for both Ansible and Helm.

Key features of this implementation:
- **Modular Design**: Separate roles for different concerns
- **Environment Support**: Easy configuration for dev/test/prod
- **Flexible Deployment**: Can deploy individual services or all together
- **Helm Integration**: Uses Helm for Kubernetes/OpenShift deployments
- **Comprehensive Configuration**: Supports all common deployment scenarios
- **Production Ready**: Includes proper resource limits, health checks, and monitoring

You can extend this pattern to add more microservices by creating additional Helm charts in the `charts/` directory and updating the main values file accordingly.