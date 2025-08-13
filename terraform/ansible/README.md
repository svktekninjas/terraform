# CF Microservices Deployment with Ansible + Helm

## Overview

This Ansible + Helm deployment solution provides a comprehensive way to deploy ConsultingFirm microservices to OpenShift/ROSA clusters. The solution uses:

- **Helm Charts**: For Kubernetes resource templating and management
- **Ansible**: For orchestration, environment management, and deployment automation
- **Tagged Execution**: For granular deployment control

## Architecture

```
ansible/
├── helm-charts/cf-microservices/     # Umbrella Helm chart
│   ├── Chart.yaml                    # Main chart metadata
│   ├── values.yaml                   # Default values
│   ├── templates/                    # Common resources (namespace, secrets)
│   └── charts/                       # Individual service charts
│       ├── naming-server/
│       ├── api-gateway/
│       ├── spring-boot-admin/
│       ├── config-service/
│       ├── excel-service/
│       ├── bench-profile/
│       ├── daily-submissions/
│       ├── interviews/
│       ├── placements/
│       └── frontend/
├── environments/                     # Environment-specific configurations
│   ├── dev/values.yaml
│   ├── test/values.yaml
│   └── prod/values.yaml
├── roles/cf-deployment/              # Ansible deployment role
│   ├── tasks/main.yml
│   ├── defaults/main.yml
│   └── vars/main.yml
└── playbooks/                        # Ansible playbooks
    ├── main.yml
    └── inventory.yml
```

## Prerequisites

1. **Required Tools**:
   ```bash
   # Install Ansible
   pip install ansible kubernetes

   # Install Helm
   curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar xz
   sudo mv linux-amd64/helm /usr/local/bin/

   # Install OpenShift CLI
   curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
   tar xzf openshift-client-linux.tar.gz
   sudo mv oc kubectl /usr/local/bin/
   ```

2. **Cluster Access**:
   ```bash
   # Login to OpenShift cluster
   oc login --token=<token> --server=<server-url>
   
   # Verify access
   oc whoami
   oc projects
   ```

3. **Docker Registry Access**:
   - Ensure ECR credentials are configured
   - Update `dockerconfigjson` in environment values files

## Deployment Guide

### 1. Complete Application Deployment

Deploy all microservices to an environment:

```bash
# Deploy to DEV environment (default)
cd ansible/playbooks
ansible-playbook -i inventory.yml main.yml

# Deploy to TEST environment
ansible-playbook -i inventory.yml main.yml -e env=test

# Deploy to PROD environment
ansible-playbook -i inventory.yml main.yml -e env=prod
```

**Tags**: `deployment`, `cf-deploy-all`, `helm-deploy`

### 2. Individual Service Deployments

Deploy specific services using tags:

#### Core Infrastructure Services

```bash
# Deploy Naming Server (Eureka) only
ansible-playbook -i inventory.yml main.yml -e deploy_naming_server_only=true --tags "cf-naming-server"

# Deploy API Gateway only
ansible-playbook -i inventory.yml main.yml -e deploy_api_gateway_only=true --tags "cf-api-gateway"

# Deploy Spring Boot Admin only
ansible-playbook -i inventory.yml main.yml -e deploy_spring_boot_admin_only=true --tags "cf-spring-boot-admin"

# Deploy Config Service only
ansible-playbook -i inventory.yml main.yml -e deploy_config_service_only=true --tags "cf-config-service"
```

#### Business Services

```bash
# Deploy all business services
ansible-playbook -i inventory.yml main.yml -e deploy_business_services_only=true --tags "cf-business-services"

# Deploy specific business services
ansible-playbook -i inventory.yml main.yml --tags "cf-excel-service"
ansible-playbook -i inventory.yml main.yml --tags "cf-bench-profile"
ansible-playbook -i inventory.yml main.yml --tags "cf-daily-submissions"
ansible-playbook -i inventory.yml main.yml --tags "cf-interviews"
ansible-playbook -i inventory.yml main.yml --tags "cf-placements"
```

#### Frontend

```bash
# Deploy Frontend only
ansible-playbook -i inventory.yml main.yml -e deploy_frontend_only=true --tags "cf-frontend"
```

### 3. Namespace Management

```bash
# Create namespace only
ansible-playbook -i inventory.yml main.yml --tags "cf-namespace"

# Verify namespace
ansible-playbook -i inventory.yml main.yml --tags "verify"
```

### 4. Verification and Status

```bash
# Run verification checks
ansible-playbook -i inventory.yml main.yml --tags "verify"

# Check deployment status
ansible-playbook -i inventory.yml main.yml --tags "status"

# Display routes
ansible-playbook -i inventory.yml main.yml --tags "routes"
```

## Service Tags Reference

| Service | Primary Tag | Alternative Tags |
|---------|-------------|------------------|
| **Master Deployment** | `deployment` | `cf-deploy-all`, `helm-deploy` |
| **Namespace** | `cf-namespace` | `namespace` |
| **Naming Server** | `cf-naming-server` | `naming-server` |
| **API Gateway** | `cf-api-gateway` | `api-gateway` |
| **Spring Boot Admin** | `cf-spring-boot-admin` | `spring-boot-admin` |
| **Config Service** | `cf-config-service` | `config-service` |
| **Excel Service** | `cf-excel-service` | `excel-service` |
| **Bench Profile** | `cf-bench-profile` | `bench-profile` |
| **Daily Submissions** | `cf-daily-submissions` | `daily-submissions` |
| **Interviews** | `cf-interviews` | `interviews` |
| **Placements** | `cf-placements` | `placements` |
| **Frontend** | `cf-frontend` | `frontend` |
| **Business Services** | `cf-business-services` | `business-services` |
| **Verification** | `cf-verify` | `verify`, `status`, `routes` |

## Environment Configuration

### DEV Environment
- **Namespace**: `cf-dev`
- **Replicas**: 1 for all services
- **Resources**: Minimal resource allocation
- **Usage**: Development and testing

### TEST Environment
- **Namespace**: `cf-test`
- **Replicas**: 1-2 per service
- **Resources**: Medium resource allocation
- **Usage**: Integration testing, UAT

### PROD Environment
- **Namespace**: `cf-prod`
- **Replicas**: 2-4 per service (high availability)
- **Resources**: Production-grade resource allocation
- **Usage**: Production workloads

## Customization

### 1. Modify Environment Values

Edit environment-specific values files:

```bash
# Edit DEV configuration
vi environments/dev/values.yaml

# Edit TEST configuration
vi environments/test/values.yaml

# Edit PROD configuration
vi environments/prod/values.yaml
```

### 2. Update Docker Registry Credentials

```bash
# Generate base64 encoded docker config
echo '{"auths":{"registry.com":{"auth":"base64-encoded-credentials"}}}' | base64 -w 0

# Update in values files
dockerSecret:
  dockerconfigjson: "<base64-encoded-config>"
```

### 3. Modify Service Resources

```yaml
# In environment values files
service-name:
  deployment:
    replicas: 3
    resources:
      limits:
        cpu: 1000m
        memory: 1Gi
      requests:
        cpu: 500m
        memory: 512Mi
```

## Troubleshooting

### 1. Check Deployment Status

```bash
# Check Helm releases
helm list -A

# Check specific release
helm status cf-microservices -n cf-dev

# Check deployment logs
oc logs -f deployment/naming-server-new -n cf-dev
```

### 2. Debug Failed Deployments

```bash
# Describe problematic pods
oc describe pod <pod-name> -n cf-dev

# Check events
oc get events -n cf-dev --sort-by='.lastTimestamp'

# View deployment status
oc get deployments -n cf-dev
```

### 3. Registry Issues

```bash
# Test registry access
oc get secret ecr-secret -n cf-dev -o yaml

# Check image pull issues
oc describe pod <pod-name> -n cf-dev | grep -A 10 "Events:"
```

### 4. Helm Debugging

```bash
# Dry run deployment
helm upgrade --install cf-microservices ./helm-charts/cf-microservices \
  -f environments/dev/values.yaml \
  --dry-run --debug

# Check template rendering
helm template cf-microservices ./helm-charts/cf-microservices \
  -f environments/dev/values.yaml
```

## Rollback Procedures

### 1. Helm Rollback

```bash
# List Helm release history
helm history cf-microservices -n cf-dev

# Rollback to previous version
helm rollback cf-microservices -n cf-dev

# Rollback to specific revision
helm rollback cf-microservices 1 -n cf-dev
```

### 2. Complete Environment Reset

```bash
# Delete the entire release
helm uninstall cf-microservices -n cf-dev

# Redeploy
ansible-playbook -i inventory.yml main.yml -e env=dev
```

## Monitoring and Validation

### 1. Health Checks

```bash
# Check all pods
oc get pods -n cf-dev

# Check services
oc get services -n cf-dev

# Check routes
oc get routes -n cf-dev
```

### 2. Application URLs

After deployment, access applications via OpenShift routes:

```bash
# Get all routes
oc get routes -n cf-dev

# Example URLs:
# https://naming-server-new-cf-dev.apps.cluster.example.com
# https://apigateway-app-cf-dev.apps.cluster.example.com
# https://spring-boot-admin-cf-dev.apps.cluster.example.com
```

## CI/CD Integration

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'test', 'prod'],
            description: 'Target environment'
        )
        choice(
            name: 'DEPLOYMENT_TYPE',
            choices: ['full', 'infrastructure', 'business', 'frontend'],
            description: 'Deployment scope'
        )
    }
    stages {
        stage('Deploy') {
            steps {
                script {
                    def tags = ""
                    switch(params.DEPLOYMENT_TYPE) {
                        case 'infrastructure':
                            tags = "--tags 'cf-naming-server,cf-api-gateway,cf-spring-boot-admin,cf-config-service'"
                            break
                        case 'business':
                            tags = "--tags 'cf-business-services'"
                            break
                        case 'frontend':
                            tags = "--tags 'cf-frontend'"
                            break
                        default:
                            tags = ""
                    }
                    
                    sh """
                        cd ansible/playbooks
                        ansible-playbook -i inventory.yml main.yml \\
                          -e env=${params.ENVIRONMENT} \\
                          ${tags}
                    """
                }
            }
        }
        stage('Verify') {
            steps {
                sh """
                    cd ansible/playbooks
                    ansible-playbook -i inventory.yml main.yml \\
                      -e env=${params.ENVIRONMENT} \\
                      --tags 'verify'
                """
            }
        }
    }
}
```

This comprehensive deployment solution provides full control over your microservices deployment while maintaining consistency across environments through Ansible automation and Helm templating.