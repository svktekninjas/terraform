# Common Excel Service Deployment Guide
## Complete Step-by-Step Tutorial for Beginners

This comprehensive guide will walk you through creating a complete Ansible role for deploying Common Excel Service using Helm charts on OpenShift/Kubernetes. You'll learn how to create the entire directory structure and write all the code from scratch, exactly as implemented in our current system.

---

## Prerequisites

- Basic understanding of Ansible, Helm, and Kubernetes/OpenShift
- Understanding of Spring Boot microservices architecture
- Access to an OpenShift/Kubernetes cluster
- Helm CLI installed (version 3.x)
- OpenShift CLI (oc) installed
- Ansible installed with kubernetes.core collection

---

## Overview

We'll create a complete deployment system including:
1. Ansible role structure for cf-deployment with Common Excel Service focus
2. Helm chart specifically for Common Excel Service
3. Environment-specific configurations
4. Business logic service deployment setup
5. Port configuration (8083) and environment variables
6. Service discovery integration with Eureka
7. Deployment automation with monitoring capabilities

---

## Part 1: Understanding Common Excel Service Architecture

### Common Excel Service Details
- **Service Name**: `excel-service`
- **Port**: `8083` (business service port)
- **Purpose**: Excel file processing and manipulation for business operations
- **Framework**: Spring Boot with Apache POI for Excel operations
- **Container Image**: `common-excel-service:latest`

### Key Features We'll Implement
- **Excel Processing**: Read, write, and manipulate Excel files
- **Service Discovery**: Registration with Eureka naming server
- **RESTful APIs**: Endpoints for Excel operations
- **Health Checks**: Kubernetes liveness/readiness probes
- **External Access**: OpenShift routes
- **Resource Management**: CPU/Memory limits
- **Environment Variables**: Dynamic configuration
- **Load Balancing**: Multiple replicas for high availability

### Service Dependencies
- **Naming Server (Eureka)**: For service discovery and registration
- **Spring Boot Admin**: For monitoring and health management
- **Config Service**: For centralized configuration management
- **No Database Dependencies**: Stateless service for file processing

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
mkdir -p helm-charts/cf-microservices/charts/excel-service/{templates,charts}

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
│       │   └── excel-service/
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
  description: ConsultingFirm microservices deployment role with Common Excel Service support
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
    - excel-service
    - business-services
    - spring-boot
    - apache-poi
    - file-processing
    - openshift
    - kubernetes
    - helm

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

# Excel Service specific defaults
excel_service_defaults:
  port: 8083
  replicas:
    dev: 1
    test: 2
    prod: 3
  resources:
    dev:
      limits:
        cpu: "500m"
        memory: "512Mi"
      requests:
        cpu: "200m"
        memory: "256Mi"
    test:
      limits:
        cpu: "1000m"
        memory: "1Gi"
      requests:
        cpu: "500m"
        memory: "512Mi"
    prod:
      limits:
        cpu: "2000m"
        memory: "2Gi"
      requests:
        cpu: "1000m"
        memory: "1Gi"

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
  excel_service: 8083
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

# Excel Service specific configuration
excel_service_config:
  service_name: "excel-service"
  image_name: "common-excel-service"
  default_port: 8083
  health_check_path: "/actuator/health"
  info_path: "/actuator/info"
  metrics_path: "/actuator/metrics"
  
  # Business logic endpoints
  api_endpoints:
    - "/api/v1/excel/upload"
    - "/api/v1/excel/download"
    - "/api/v1/excel/process"
    - "/api/v1/excel/convert"
    - "/api/v1/excel/validate"
  
  # File size limits
  file_limits:
    max_file_size: "50MB"
    max_request_size: "100MB"
    
  # Excel processing configuration
  excel_config:
    supported_formats: ["xlsx", "xls", "csv"]
    max_rows_per_sheet: 65536
    max_sheets_per_file: 10
    temp_directory: "/tmp/excel-processing"
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
      - "Excel Service Port: {{ service_ports.excel_service }}"

- name: Include ECR token management tasks
  include_tasks: ecr-token-management.yml
  when: ecr_token_management_enabled | bool

- name: Include microservices deployment tasks
  include_tasks: cf-microservices.yml
  tags:
    - cf-deployment
    - microservices
    - excel-service
    - business-services
```

### Step 7: Create Microservices Deployment Tasks

Create `roles/cf-deployment/tasks/cf-microservices.yml`:

```yaml
---
# CF Microservices deployment tasks with Excel Service focus

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

- name: Deploy CF microservices using Helm (Excel Service Only)
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
      # Enable only Excel Service
      excelService:
        enabled: true
      namingServer:
        enabled: false
      apiGateway:
        enabled: false
      springBootAdmin:
        enabled: false
      configService:
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
      # Excel Service specific configuration
      excel-service:
        image:
          repository: common-excel-service
          tag: latest
        service:
          port: 8083
        deployment:
          replicas: "{{ replica_counts[cf_environment]['excel_service'] }}"
          env: "{{ excel_service_env_vars | default([]) }}"
          resources: "{{ excel_service_defaults.resources[cf_environment] }}"
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
  when: deploy_excel_service_only | default(false)
  tags:
    - helm
    - cf-deployment
    - excel-service

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
  when: not (deploy_excel_service_only | default(false))
  tags:
    - helm
    - cf-deployment

- name: Wait for Excel Service deployment to be ready
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    name: excel-service
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
    - excel-service

- name: Get Excel Service deployment status
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    name: excel-service
    namespace: "{{ target_namespace }}"
  register: excel_service_deployment
  when: show_deployment_status | bool
  tags:
    - status
    - excel-service

- name: Display Excel Service deployment status
  debug:
    msg:
      - "Excel Service Deployment Status:"
      - "Ready Replicas: {{ excel_service_deployment.resources[0].status.readyReplicas | default(0) }}"
      - "Available Replicas: {{ excel_service_deployment.resources[0].status.availableReplicas | default(0) }}"
      - "Updated Replicas: {{ excel_service_deployment.resources[0].status.updatedReplicas | default(0) }}"
      - "Service Port: {{ service_ports.excel_service }}"
  when: 
    - show_deployment_status | bool
    - excel_service_deployment.resources is defined
    - excel_service_deployment.resources | length > 0
  tags:
    - status
    - excel-service

- name: Test Excel Service health endpoint
  uri:
    url: "http://excel-service.{{ target_namespace }}.svc.cluster.local:8083/actuator/health"
    method: GET
    timeout: 30
  register: excel_health_check
  ignore_errors: true
  when: verify_deployment | bool
  tags:
    - health-check
    - excel-service

- name: Display Excel Service health check result
  debug:
    msg:
      - "Excel Service Health Check:"
      - "Status Code: {{ excel_health_check.status | default('Failed') }}"
      - "Response: {{ excel_health_check.json | default('No response') }}"
  when: 
    - verify_deployment | bool
    - excel_health_check is defined
  tags:
    - health-check
    - excel-service
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
description: A Helm chart for ConsultingFirm microservices including Common Excel Service
type: application
version: 0.1.0
appVersion: "1.0.0"
maintainers:
  - name: ConsultingFirm DevOps Team
    email: devops@consultingfirm.com
keywords:
  - microservices
  - spring-boot
  - excel-service
  - business-services
  - file-processing
  - apache-poi
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
    port: 8083
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

### Step 10: Create Excel Service Specific Helm Chart

Create `helm-charts/cf-microservices/charts/excel-service/Chart.yaml`:

```yaml
apiVersion: v2
name: excel-service
description: Common Excel Service Helm chart for file processing operations
type: application
version: 0.1.0
appVersion: "1.0.0"
maintainers:
  - name: ConsultingFirm DevOps Team
    email: devops@consultingfirm.com
keywords:
  - excel-service
  - file-processing
  - business-services
  - spring-boot
  - apache-poi
  - microservices
```

Create `helm-charts/cf-microservices/charts/excel-service/values.yaml`:

```yaml
image:
  repository: common-excel-service
  tag: latest
  pullPolicy: Always

service:
  type: ClusterIP
  port: 8083
  targetPort: 8083

deployment:
  replicas: 2
  env:
    - name: SERVER_PORT
      value: "8083"
    - name: SPRING_PROFILES_ACTIVE
      value: "openshift"
    - name: EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE
      value: "http://naming-server-new:8761/eureka"
    - name: EUREKA_INSTANCE_PREFER_IP_ADDRESS
      value: "true"
    - name: EUREKA_INSTANCE_HOSTNAME
      value: "excel-service"
    - name: SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL
      value: "http://excel-service:8083"
    - name: SPRING_BOOT_ADMIN_CLIENT_URL
      value: "http://spring-boot-admin:8082"
    - name: SPRING_CLOUD_CONFIG_URI
      value: "http://config-service:8888"
    - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
      value: "health,info,metrics,env"
    - name: MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS
      value: "always"
    - name: LOGGING_LEVEL_ROOT
      value: "INFO"
    - name: LOGGING_LEVEL_COM_CONSULTINGFIRM
      value: "DEBUG"
    # Excel Service specific environment variables
    - name: EXCEL_MAX_FILE_SIZE
      value: "50MB"
    - name: EXCEL_MAX_REQUEST_SIZE
      value: "100MB"
    - name: EXCEL_TEMP_DIRECTORY
      value: "/tmp/excel-processing"
    - name: EXCEL_SUPPORTED_FORMATS
      value: "xlsx,xls,csv"
    - name: EXCEL_MAX_ROWS_PER_SHEET
      value: "65536"
    - name: EXCEL_MAX_SHEETS_PER_FILE
      value: "10"
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

### Step 11: Create Excel Service Deployment Template

Create `helm-charts/cf-microservices/charts/excel-service/templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: excel-service
  namespace: {{ .Values.global.namespace }}
  labels:
    app: excel-service
    version: {{ .Chart.AppVersion }}
    component: business-service
    service-type: file-processing
spec:
  replicas: {{ .Values.deployment.replicas }}
  selector:
    matchLabels:
      app: excel-service
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: excel-service
        version: {{ .Chart.AppVersion }}
        component: business-service
        service-type: file-processing
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "{{ .Values.service.targetPort }}"
        prometheus.io/path: "/actuator/prometheus"
    spec:
      {{- if .Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml .Values.global.imagePullSecrets | nindent 8 }}
      {{- end }}
      containers:
      - name: excel-service
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
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: {{ .Values.service.targetPort }}
          initialDelaySeconds: 120
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: {{ .Values.service.targetPort }}
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        # Volume mounts for temporary file processing
        volumeMounts:
        - name: temp-storage
          mountPath: /tmp/excel-processing
        - name: logs
          mountPath: /logs
      volumes:
      - name: temp-storage
        emptyDir:
          sizeLimit: 1Gi
      - name: logs
        emptyDir:
          sizeLimit: 500Mi
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
```

### Step 12: Create Excel Service Service Template

Create `helm-charts/cf-microservices/charts/excel-service/templates/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: excel-service
  namespace: {{ .Values.global.namespace }}
  labels:
    app: excel-service
    version: {{ .Chart.AppVersion }}
    component: business-service
    service-type: file-processing
  annotations:
    service.beta.openshift.io/serving-cert-secret-name: excel-service-tls
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
      protocol: TCP
      name: http
  selector:
    app: excel-service
  sessionAffinity: None
```

### Step 13: Create Excel Service Route Template

Create `helm-charts/cf-microservices/charts/excel-service/templates/route.yaml`:

```yaml
{{- if .Values.route.enabled }}
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: excel-service
  namespace: {{ .Values.global.namespace }}
  labels:
    app: excel-service
    version: {{ .Chart.AppVersion }}
    component: business-service
    service-type: file-processing
  annotations:
    haproxy.router.openshift.io/timeout: "300s"
    haproxy.router.openshift.io/balance: "roundrobin"
spec:
  {{- if .Values.route.host }}
  host: {{ .Values.route.host }}
  {{- end }}
  to:
    kind: Service
    name: excel-service
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
excelService:
  enabled: true

# Excel Service specific configuration for development
excel-service:
  image:
    repository: common-excel-service
    tag: latest
  service:
    port: 8083
  deployment:
    replicas: 1
    env:
      - name: SERVER_PORT
        value: "8083"
      - name: SPRING_PROFILES_ACTIVE
        value: "dev,openshift"
      - name: EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE
        value: "http://naming-server-new:8761/eureka"
      - name: EUREKA_INSTANCE_PREFER_IP_ADDRESS
        value: "true"
      - name: EUREKA_INSTANCE_HOSTNAME
        value: "excel-service"
      - name: SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL
        value: "http://excel-service:8083"
      - name: SPRING_BOOT_ADMIN_CLIENT_URL
        value: "http://spring-boot-admin:8082"
      - name: SPRING_CLOUD_CONFIG_URI
        value: "http://config-service:8888"
      - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
        value: "health,info,metrics,env,loggers,configprops"
      - name: MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS
        value: "always"
      - name: LOGGING_LEVEL_ROOT
        value: "INFO"
      - name: LOGGING_LEVEL_COM_CONSULTINGFIRM
        value: "DEBUG"
      # Excel Service specific environment variables for development
      - name: EXCEL_MAX_FILE_SIZE
        value: "10MB"
      - name: EXCEL_MAX_REQUEST_SIZE
        value: "20MB"
      - name: EXCEL_TEMP_DIRECTORY
        value: "/tmp/excel-processing"
      - name: EXCEL_SUPPORTED_FORMATS
        value: "xlsx,xls,csv"
      - name: EXCEL_MAX_ROWS_PER_SHEET
        value: "10000"
      - name: EXCEL_MAX_SHEETS_PER_FILE
        value: "5"
      - name: EXCEL_PROCESSING_TIMEOUT_SECONDS
        value: "300"
      - name: EXCEL_ENABLE_DEBUG_LOGGING
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

# Service deployment flags for dev
deploy_naming_server_only: false
deploy_api_gateway_only: false
deploy_spring_boot_admin_only: false
deploy_config_service_only: false
deploy_business_services_only: false
deploy_excel_service_only: false
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

# Excel Service specific dev configuration
excel_service_dev_config:
  enable_debug_logging: true
  file_size_limit: "10MB"
  processing_timeout: 300
  temp_storage_size: "1Gi"
  
# Dev-specific labels
environment_labels:
  environment: dev
  purpose: development
  team: consultingfirm
  service-category: business-logic
```

---

## Part 7: Creating the Main Playbook

### Step 15: Create Main Playbook

Create `playbooks/main.yml`:

```yaml
---
- name: Deploy ConsultingFirm Microservices with Excel Service
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
          - "Excel Service Port: {{ service_ports.excel_service | default('8083') }}"
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
        - excel-service
        - business-services
```

---

## Part 8: Excel Service Business Logic Configuration

### Step 16: Advanced Excel Service Environment Variables

For production-ready Excel service with comprehensive configuration:

```yaml
# Advanced Excel Service Configuration (add to deployment-values.yaml)
excel-service:
  deployment:
    env:
      # Server Configuration
      - name: SERVER_PORT
        value: "8083"
      - name: SPRING_PROFILES_ACTIVE
        value: "openshift,excel-service"
      
      # Service Discovery
      - name: EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE
        value: "http://naming-server-new:8761/eureka"
      - name: EUREKA_INSTANCE_PREFER_IP_ADDRESS
        value: "true"
      - name: EUREKA_INSTANCE_HOSTNAME
        value: "excel-service"
      - name: EUREKA_INSTANCE_LEASE_RENEWAL_INTERVAL_IN_SECONDS
        value: "30"
      - name: EUREKA_INSTANCE_LEASE_EXPIRATION_DURATION_IN_SECONDS
        value: "90"
      
      # Spring Boot Admin Integration
      - name: SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL
        value: "http://excel-service:8083"
      - name: SPRING_BOOT_ADMIN_CLIENT_URL
        value: "http://spring-boot-admin:8082"
      - name: SPRING_BOOT_ADMIN_CLIENT_AUTO_REGISTRATION
        value: "true"
      
      # Configuration Management
      - name: SPRING_CLOUD_CONFIG_URI
        value: "http://config-service:8888"
      - name: SPRING_CLOUD_CONFIG_FAIL_FAST
        value: "false"
      - name: SPRING_CLOUD_CONFIG_RETRY_INITIAL_INTERVAL
        value: "1000"
      
      # Management Endpoints
      - name: MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
        value: "health,info,metrics,env,loggers,configprops,prometheus"
      - name: MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS
        value: "always"
      - name: MANAGEMENT_HEALTH_DISKSPACE_ENABLED
        value: "true"
      - name: MANAGEMENT_METRICS_EXPORT_PROMETHEUS_ENABLED
        value: "true"
      
      # Logging Configuration
      - name: LOGGING_LEVEL_ROOT
        value: "INFO"
      - name: LOGGING_LEVEL_COM_CONSULTINGFIRM
        value: "DEBUG"
      - name: LOGGING_LEVEL_ORG_APACHE_POI
        value: "WARN"
      - name: LOGGING_PATTERN_CONSOLE
        value: "%d{yyyy-MM-dd HH:mm:ss} - %msg%n"
      
      # Excel Processing Configuration
      - name: EXCEL_MAX_FILE_SIZE
        value: "50MB"
      - name: EXCEL_MAX_REQUEST_SIZE
        value: "100MB"
      - name: EXCEL_TEMP_DIRECTORY
        value: "/tmp/excel-processing"
      - name: EXCEL_SUPPORTED_FORMATS
        value: "xlsx,xls,csv"
      - name: EXCEL_MAX_ROWS_PER_SHEET
        value: "65536"
      - name: EXCEL_MAX_SHEETS_PER_FILE
        value: "10"
      - name: EXCEL_PROCESSING_TIMEOUT_SECONDS
        value: "600"
      - name: EXCEL_ENABLE_STREAMING
        value: "true"
      - name: EXCEL_BUFFER_SIZE
        value: "8192"
      
      # File Upload Configuration
      - name: SPRING_SERVLET_MULTIPART_MAX_FILE_SIZE
        value: "50MB"
      - name: SPRING_SERVLET_MULTIPART_MAX_REQUEST_SIZE
        value: "100MB"
      - name: SPRING_SERVLET_MULTIPART_RESOLVE_LAZILY
        value: "true"
      
      # Thread Pool Configuration
      - name: EXCEL_THREAD_POOL_CORE_SIZE
        value: "5"
      - name: EXCEL_THREAD_POOL_MAX_SIZE
        value: "20"
      - name: EXCEL_THREAD_POOL_QUEUE_CAPACITY
        value: "100"
      
      # Cache Configuration
      - name: SPRING_CACHE_TYPE
        value: "caffeine"
      - name: SPRING_CACHE_CAFFEINE_SPEC
        value: "maximumSize=1000,expireAfterWrite=300s"
```

---

## Part 9: Deployment Execution Instructions

### Step 17: Deploy Excel Service Only

```bash
# Navigate to ansible directory
cd ansible

# Deploy only Excel Service
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_excel_service_only=true" \
  -e "environment=dev"
```

### Step 18: Deploy with Custom Environment Variables

```bash
# Deploy Excel Service with custom configuration
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_excel_service_only=true" \
  -e "environment=dev" \
  -e "excel_service_env_vars=[
    {'name': 'SERVER_PORT', 'value': '8083'},
    {'name': 'SPRING_PROFILES_ACTIVE', 'value': 'dev,openshift'},
    {'name': 'EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE', 'value': 'http://naming-server-new:8761/eureka'},
    {'name': 'EXCEL_MAX_FILE_SIZE', 'value': '25MB'},
    {'name': 'EXCEL_PROCESSING_TIMEOUT_SECONDS', 'value': '300'},
    {'name': 'LOGGING_LEVEL_COM_CONSULTINGFIRM', 'value': 'DEBUG'}
  ]"
```

### Step 19: Deploy All Services

```bash
# Deploy all microservices including Excel Service
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "environment=dev"
```

### Step 20: Deploy with Scaling

```bash
# Deploy Excel Service with multiple replicas
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_excel_service_only=true" \
  -e "environment=test" \
  -e "excel_service_replicas=3"
```

---

## Part 10: Verification and Testing

### Step 21: Verify Deployment

```bash
# Check Helm release
helm list -n cf-dev

# Check deployment status
oc get deployment excel-service -n cf-dev

# Check pod status
oc get pods -l app=excel-service -n cf-dev

# Check service
oc get svc excel-service -n cf-dev

# Check route
oc get route excel-service -n cf-dev

# Check resource usage
oc top pods -l app=excel-service -n cf-dev
```

### Step 22: Test Excel Service Functionality

```bash
# Get Excel Service URL
EXCEL_URL="https://$(oc get route excel-service -n cf-dev -o jsonpath='{.spec.host}')"

# Test health endpoint
curl -k "$EXCEL_URL/actuator/health"

# Test info endpoint
curl -k "$EXCEL_URL/actuator/info"

# Test metrics endpoint
curl -k "$EXCEL_URL/actuator/metrics"

# Test Excel Service specific endpoints
curl -k "$EXCEL_URL/actuator/metrics/excel.processing.time"
curl -k "$EXCEL_URL/actuator/metrics/excel.files.processed"

# Test business endpoints (if implemented)
curl -k "$EXCEL_URL/api/v1/excel/health"
```

### Step 23: Load Testing Excel Service

```bash
# Test file upload capability (with a small test file)
curl -k -X POST "$EXCEL_URL/api/v1/excel/upload" \
  -F "file=@test.xlsx" \
  -F "processType=validate"

# Test multiple concurrent requests
for i in {1..10}; do
  curl -k "$EXCEL_URL/actuator/health" &
done
wait
```

---

## Part 11: Advanced Excel Service Features

### Step 24: Excel Processing Monitoring

Add monitoring-specific configuration:

```yaml
excel-service:
  deployment:
    env:
      # Monitoring and metrics
      - name: MANAGEMENT_METRICS_TAGS_APPLICATION
        value: "excel-service"
      - name: MANAGEMENT_METRICS_TAGS_ENVIRONMENT
        value: "dev"
      - name: MANAGEMENT_METRICS_DISTRIBUTION_PERCENTILES_HISTOGRAM_HTTP_SERVER_REQUESTS
        value: "true"
      - name: MANAGEMENT_METRICS_DISTRIBUTION_PERCENTILES_HTTP_SERVER_REQUESTS
        value: "0.5,0.9,0.95,0.99"
      
      # Custom Excel metrics
      - name: EXCEL_METRICS_ENABLED
        value: "true"
      - name: EXCEL_METRICS_PROCESSING_TIME_ENABLED
        value: "true"
      - name: EXCEL_METRICS_FILE_SIZE_HISTOGRAM_ENABLED
        value: "true"
```

### Step 25: Excel Service Security Configuration

```yaml
excel-service:
  deployment:
    env:
      # Security settings
      - name: EXCEL_SECURITY_ENABLED
        value: "true"
      - name: EXCEL_ALLOWED_FILE_EXTENSIONS
        value: "xlsx,xls,csv"
      - name: EXCEL_SCAN_FOR_MACROS
        value: "true"
      - name: EXCEL_REJECT_MACRO_FILES
        value: "true"
      - name: EXCEL_MAX_FORMULA_COMPLEXITY
        value: "1000"
      - name: EXCEL_SANITIZE_CELL_CONTENT
        value: "true"
```

---

## Part 12: Troubleshooting Guide

### Common Issues and Solutions

1. **Excel Service Not Starting**
   ```bash
   # Check pod logs
   oc logs deployment/excel-service -n cf-dev
   
   # Check events
   oc get events -n cf-dev --field-selector involvedObject.name=excel-service
   
   # Check resource constraints
   oc describe pod -l app=excel-service -n cf-dev
   ```

2. **File Processing Failures**
   ```bash
   # Check Excel processing logs
   oc logs deployment/excel-service -n cf-dev | grep -i "excel\|processing\|error"
   
   # Check temporary directory
   oc exec deployment/excel-service -n cf-dev -- ls -la /tmp/excel-processing/
   
   # Check disk space
   oc exec deployment/excel-service -n cf-dev -- df -h
   ```

3. **Performance Issues**
   ```bash
   # Check resource usage
   oc top pods -l app=excel-service -n cf-dev
   
   # Check thread pool metrics
   curl -k "$EXCEL_URL/actuator/metrics/excel.thread.pool.active"
   curl -k "$EXCEL_URL/actuator/metrics/excel.thread.pool.queue.size"
   ```

4. **Service Discovery Issues**
   ```bash
   # Check Eureka registration
   EUREKA_URL="https://$(oc get route naming-server-new -n cf-dev -o jsonpath='{.spec.host}')"
   curl -k "$EUREKA_URL/eureka/apps/EXCEL-SERVICE"
   
   # Test service connectivity
   oc exec deployment/excel-service -n cf-dev -- curl -s http://naming-server-new:8761/eureka/apps
   ```

---

## Part 13: Scaling and Performance Optimization

### Step 26: Horizontal Pod Autoscaling

Create HPA configuration for Excel Service:

```bash
# Create HPA based on CPU and memory
oc autoscale deployment excel-service \
  --min=2 \
  --max=10 \
  --cpu-percent=70 \
  -n cf-dev

# Check HPA status
oc get hpa excel-service -n cf-dev
```

### Step 27: Resource Optimization

```yaml
# Production resource configuration
excel-service:
  deployment:
    resources:
      limits:
        cpu: 2000m
        memory: 2Gi
        ephemeral-storage: 5Gi
      requests:
        cpu: 1000m
        memory: 1Gi
        ephemeral-storage: 2Gi
```

---

## Part 14: Cleanup and Maintenance

### Step 28: Update Excel Service

```bash
# Update configuration and restart
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_excel_service_only=true" \
  -e "environment=dev" \
  -e "excel_service_env_vars=[{'name': 'EXCEL_MAX_FILE_SIZE', 'value': '100MB'}]"
```

### Step 29: Rolling Updates

```bash
# Update image tag
helm upgrade cf-microservices-dev helm-charts/cf-microservices \
  -n cf-dev \
  -f environments/dev/deployment-values.yaml \
  --set excel-service.image.tag=new-version
```

### Step 30: Cleanup

```bash
# Remove Excel Service only
oc delete deployment excel-service -n cf-dev
oc delete service excel-service -n cf-dev  
oc delete route excel-service -n cf-dev

# Remove entire release
helm uninstall cf-microservices-dev -n cf-dev
```

---

## Success Criteria Checklist

- [ ] Complete directory structure created
- [ ] All Ansible role files properly configured
- [ ] Helm chart created with correct templates
- [ ] Environment-specific configurations set up
- [ ] Excel Service deploys successfully
- [ ] Service accessible on port 8083
- [ ] Health endpoints responding correctly
- [ ] File processing endpoints functional
- [ ] Service registration with Eureka working
- [ ] Spring Boot Admin integration active
- [ ] Routes properly configured
- [ ] Environment variables set correctly
- [ ] Resource limits applied
- [ ] Monitoring endpoints enabled
- [ ] Load balancing working across replicas
- [ ] File upload/processing working
- [ ] Performance metrics collecting

---

## Conclusion

This comprehensive guide provides everything needed to create a complete Common Excel Service deployment from scratch. The modular structure allows for easy maintenance and scaling, while the environment-specific configurations ensure proper separation between development, test, and production environments.

The Excel Service is configured with:
- **File Processing**: Robust Excel file handling with Apache POI
- **Business Logic**: RESTful APIs for Excel operations
- **Monitoring**: Complete observability with metrics and health checks  
- **Security**: File validation and macro scanning
- **Performance**: Optimized for high-throughput file processing
- **Integration**: Seamless integration with the microservices ecosystem

---

## Contact & Support

For issues or questions:
- Check Excel Service logs: `oc logs deployment/excel-service -n cf-dev`
- Review file processing metrics: `curl -k $EXCEL_URL/actuator/metrics`
- Test business endpoints manually
- Contact DevOps team for infrastructure issues