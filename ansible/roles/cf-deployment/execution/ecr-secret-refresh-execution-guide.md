# ECR Secret Refresh Task - Execution Guide

## Overview

The ECR Secret Refresh task is integrated into the `cf-deployment` role to automatically create and refresh ECR authentication secrets for cross-account image pulling. This task creates Docker registry secrets that enable OpenShift pods to authenticate with Amazon ECR repositories.

## Task Purpose

- **Automated ECR Authentication**: Creates Kubernetes docker-registry secrets with fresh ECR tokens
- **Cross-Account Support**: Enables access to ECR repositories in different AWS accounts
- **Token Management**: Handles 12-hour ECR token lifecycle automatically
- **Deployment Integration**: Optionally restarts deployments to use new secrets

## Configuration

### Default Configuration (`defaults/main.yml`)

```yaml
# ECR Authentication Configuration
ecr_config:
  registry_url: "818140567777.dkr.ecr.us-east-1.amazonaws.com"
  aws_region: "us-east-1"
  secret_name: "ecr-secret"
  restart_deployments: false
  token_validity_hours: 12

# ECR refresh control flags
refresh_ecr_secret: false
ecr_refresh_enabled: "{{ refresh_ecr_secret | default(false) }}"
```

### Environment-Specific Configuration (`environments/dev/deployment-values.yaml`)

```yaml
# ECR Authentication Configuration for Dev Environment
ecr_config:
  registry_url: "818140567777.dkr.ecr.us-east-1.amazonaws.com"
  aws_region: "us-east-1"
  secret_name: "ecr-secret"
  restart_deployments: true  # Auto-restart deployments in dev
  token_validity_hours: 12

# ECR refresh control (can be overridden via command line)
refresh_ecr_secret: false
```

## Prerequisites

### 1. AWS CLI Configuration
```bash
# Verify AWS CLI is installed
aws --version

# Verify AWS credentials
aws sts get-caller-identity
```

### 2. OpenShift Access
```bash
# Verify OpenShift connection
oc whoami

# Verify namespace access
oc get namespace cf-dev
```

### 3. Required Permissions
The AWS user/role must have the following permissions:
- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:BatchGetImage`
- `ecr:GetDownloadUrlForLayer`

## Execution Methods

### Method 1: Enable ECR Refresh with Deployment

```bash
# Enable ECR refresh and deploy
ansible-playbook -i localhost, playbooks/main.yml \
  -e "env=dev" \
  -e "refresh_ecr_secret=true" \
  --tags "cf-deployment"
```

### Method 2: ECR Refresh Only

```bash
# Refresh ECR secret only
ansible-playbook -i localhost, playbooks/main.yml \
  -e "env=dev" \
  -e "refresh_ecr_secret=true" \
  --tags "ecr-refresh"
```

### Method 3: Environment-Specific Configuration Override

```bash
# Override ECR configuration for specific environment
ansible-playbook -i localhost, playbooks/main.yml \
  -e "env=prod" \
  -e "refresh_ecr_secret=true" \
  -e "ecr_config.restart_deployments=false" \
  --tags "ecr-refresh"
```

### Method 4: Custom ECR Registry

```bash
# Use different ECR registry
ansible-playbook -i localhost, playbooks/main.yml \
  -e "env=dev" \
  -e "refresh_ecr_secret=true" \
  -e "ecr_config.registry_url=123456789012.dkr.ecr.us-west-2.amazonaws.com" \
  -e "ecr_config.aws_region=us-west-2" \
  --tags "ecr-refresh"
```

## Execution Output

### Successful Execution

```
TASK [cf-deployment : ECR Secret Refresh - Start] ******************************
ok: [localhost] => {
    "msg": [
        "Starting ECR secret refresh process",
        "Registry: 818140567777.dkr.ecr.us-east-1.amazonaws.com",
        "Namespace: cf-dev",
        "Secret Name: ecr-secret"
    ]
}

TASK [cf-deployment : Get ECR authorization token] *****************************
ok: [localhost]

TASK [cf-deployment : Create ECR docker registry secret] ***********************
changed: [localhost]

TASK [cf-deployment : Display ECR secret status] *******************************
ok: [localhost] => {
    "msg": [
        "ECR Secret Status:",
        "  Name: ecr-secret",
        "  Namespace: cf-dev",
        "  Created: 2025-07-23T22:45:25Z",
        "  Registry: 818140567777.dkr.ecr.us-east-1.amazonaws.com",
        "  Token validity: 12 hours",
        "  Next refresh needed: 2025-07-24 10:45:25 UTC"
    ]
}
```

## Validation

### 1. Verify Secret Creation

```bash
# Check if ECR secret exists
oc get secret ecr-secret -n cf-dev

# Verify secret details
oc describe secret ecr-secret -n cf-dev

# Check secret content (without exposing token)
oc get secret ecr-secret -n cf-dev -o jsonpath='{.type}'
# Should output: kubernetes.io/dockerconfigjson
```

### 2. Test Image Pull Authentication

```bash
# Create test pod using ECR image
oc run ecr-test \
  --image=818140567777.dkr.ecr.us-east-1.amazonaws.com/consultingfirm/frontend:latest \
  --restart=Never \
  -n cf-dev

# Check pod status
oc get pod ecr-test -n cf-dev

# Check pod events for image pull status
oc describe pod ecr-test -n cf-dev

# Clean up test pod
oc delete pod ecr-test -n cf-dev
```

### 3. Verify Deployment Integration

```bash
# Check that deployments use imagePullSecrets
oc get deployment naming-server-new -n cf-dev -o yaml | grep -A 5 imagePullSecrets

# Restart a deployment to test secret usage
oc rollout restart deployment/naming-server-new -n cf-dev

# Monitor deployment rollout
oc rollout status deployment/naming-server-new -n cf-dev

# Check pod image pull status
oc get pods -n cf-dev | grep naming-server
oc describe pod <pod-name> -n cf-dev | grep -A 10 Events
```

## Troubleshooting

### Issue 1: AWS Credentials Not Configured

**Error:**
```
TASK [cf-deployment : Test AWS credentials] ************************************
failed: [localhost] => {"msg": "AWS credentials are not configured or invalid"}
```

**Solution:**
```bash
# Configure AWS credentials
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=us-east-1
```

### Issue 2: ECR Authorization Failed

**Error:**
```
TASK [cf-deployment : Get ECR authorization token] *****************************
failed: [localhost] => {"msg": "Failed to get ECR authorization token"}
```

**Solutions:**
```bash
# Check AWS permissions
aws ecr get-authorization-token --region us-east-1

# Verify ECR registry URL is correct
aws ecr describe-repositories --region us-east-1

# Check cross-account permissions
aws sts assume-role --role-arn arn:aws:iam::818140567777:role/ECRCrossAccountRole \
  --role-session-name test-session
```

### Issue 3: Image Pull Still Failing After Secret Creation

**Symptoms:**
- Secret created successfully
- Pods still show `ImagePullBackOff` or `ErrImagePull`

**Diagnosis:**
```bash
# Check pod events for specific error
oc describe pod <failing-pod> -n cf-dev | tail -20

# Verify deployment uses imagePullSecrets
oc get deployment <deployment-name> -n cf-dev -o yaml | grep -A 5 imagePullSecrets

# Check secret content
oc get secret ecr-secret -n cf-dev -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq .
```

**Solutions:**
```bash
# Refresh ECR secret
ansible-playbook -i localhost, playbooks/main.yml \
  -e "env=dev" \
  -e "refresh_ecr_secret=true" \
  --tags "ecr-refresh"

# Restart deployment to pick up new secret
oc rollout restart deployment/<deployment-name> -n cf-dev

# Verify deployment template has imagePullSecrets configured
```

### Issue 4: Cross-Account Access Denied

**Error in Pod Events:**
```
Failed to pull image: denied: User: arn:aws:iam::606639739464:user/svktek_admin 
is not authorized to perform: ecr:BatchGetImage on resource: 
arn:aws:ecr:us-east-1:818140567777:repository/consultingfirm/frontend
```

**Solution:**
This indicates AWS cross-account permissions need to be configured. Contact AWS administrator to:
1. Set up ECR resource-based policies
2. Configure cross-account IAM roles
3. Establish proper trust relationships

## Automation and Scheduling

### Cron Job for Automatic Refresh

Create a cron job to refresh ECR secrets automatically:

```bash
# Add to crontab (refresh every 10 hours)
0 */10 * * * cd /path/to/ansible && ansible-playbook -i localhost, playbooks/main.yml -e "env=dev" -e "refresh_ecr_secret=true" --tags "ecr-refresh" >> /var/log/ecr-refresh.log 2>&1
```

### Multiple Environment Refresh

```bash
# Refresh all environments
for env in dev test prod; do
  echo "Refreshing ECR secret for $env"
  ansible-playbook -i localhost, playbooks/main.yml \
    -e "env=$env" \
    -e "refresh_ecr_secret=true" \
    --tags "ecr-refresh"
done
```

## Integration with CI/CD

### GitLab CI Example

```yaml
refresh-ecr-secrets:
  stage: deploy
  script:
    - ansible-playbook -i localhost, playbooks/main.yml 
      -e "env=${CI_ENVIRONMENT_NAME}" 
      -e "refresh_ecr_secret=true" 
      --tags "ecr-refresh"
  rules:
    - if: $CI_ECR_REFRESH == "true"
```

### GitHub Actions Example

```yaml
- name: Refresh ECR Secrets
  run: |
    ansible-playbook -i localhost, playbooks/main.yml \
      -e "env=${{ github.event.inputs.environment }}" \
      -e "refresh_ecr_secret=true" \
      --tags "ecr-refresh"
  if: github.event.inputs.refresh_ecr == 'true'
```

## File References

- **Task File**: `roles/cf-deployment/tasks/refresh-ecr-secret.yml`
- **Main Orchestrator**: `roles/cf-deployment/tasks/main.yml:24-31`
- **Default Variables**: `roles/cf-deployment/defaults/main.yml:30-40`
- **Environment Config**: `environments/dev/deployment-values.yaml:82-91`
- **Execution Guide**: `roles/cf-deployment/execution/ecr-secret-refresh-execution-guide.md`

## Security Considerations

1. **Token Security**: ECR tokens are stored as Kubernetes secrets with base64 encoding
2. **Token Rotation**: Tokens automatically expire after 12 hours
3. **Access Control**: Secrets are namespace-scoped and follow RBAC
4. **Audit Trail**: All secret operations are logged in Kubernetes audit logs
5. **No Persistent Storage**: Tokens are regenerated, not stored persistently

---

**Generated**: 2025-07-23  
**Environment**: ROSA/OpenShift 4.x  
**Ansible Version**: 2.18+  
**Role Version**: cf-deployment v1.0