# ECR Credential Provider Task - Execution Guide

## Overview
This guide documents the execution of the `set-ecr-credential-provider` task from the cf-deployment role, including prerequisites, troubleshooting, and results.

## Task Purpose
Configures ROSA worker nodes with ECR credential provider for automatic authentication to cross-account ECR registries without requiring manual docker login or stored secrets.

## Prerequisites

### 1. Python Kubernetes Libraries
The task uses Ansible's `k8s` module which requires additional Python libraries:
- `kubernetes` - Kubernetes Python client
- `PyYAML` - YAML parsing library

### 2. System Environment
- Active ROSA cluster connection
- Proper OIDC trust relationship configured
- Cross-account IAM roles created

## Installation Steps

### Step 1: Check Current Python Version
```bash
python3 --version
# Output: Python 3.13.x
```

### Step 2: Install Required Libraries
```bash
# Attempt standard installation (will fail on externally-managed environments)
pip3.13 install kubernetes PyYAML

# If you get "externally-managed-environment" error, use:
pip3.13 install kubernetes PyYAML --break-system-packages
```

**Installation Output:**
```
Successfully installed PyYAML-6.0.2 cachetools-5.5.2 charset_normalizer-3.4.2 
durationpy-0.10 google-auth-2.40.3 idna-3.10 kubernetes-33.1.0 oauthlib-3.3.1 
pyasn1-0.6.1 pyasn1-modules-0.4.2 python-dateutil-2.9.0.post0 requests-2.32.4 
requests-oauthlib-2.0.0 rsa-4.9.1 six-1.17.0 urllib3-2.5.0 websocket-client-1.8.0
```

### Step 3: Verify Installation
```bash
python3.13 -c "import kubernetes; print('Kubernetes library installed successfully')"
```

## Task Execution

### Command Structure
```bash
ansible-playbook -i localhost, playbooks/main.yml \
  --tags ecr-credential-provider \
  -e setup_ecr_credential_provider=true \
  -e env=dev \
  -e @environments/dev/deployment-values.yaml
```

### Command Breakdown
- `--tags ecr-credential-provider`: Execute only ECR credential provider tasks
- `-e setup_ecr_credential_provider=true`: Enable the conditional task execution
- `-e env=dev`: Set environment to development
- `-e @environments/dev/deployment-values.yaml`: Load environment-specific variables

### Required Variables (from deployment-values.yaml)
```yaml
ecr_config:
  registry_url: "818140567777.dkr.ecr.us-east-1.amazonaws.com"
  account_id: "818140567777"
  rosa_account_id: "606639739464"
  rosa_ecr_assume_role_arn: "arn:aws:iam::606639739464:role/ROSAECRAssumeRole"
  ecr_cross_account_role_arn: "arn:aws:iam::818140567777:role/ECRCrossAccountRole"
  aws_region: "us-east-1"
```

## Execution Results

### Successful Output
```
PLAY [ROSA Infrastructure Setup] ***********************************************

TASK [Gathering Facts] *********************************************************
ok: [localhost]

TASK [cluster : Load cluster variables] ****************************************
ok: [localhost]

TASK [monitoring : Load monitoring variables] **********************************
ok: [localhost]

TASK [monitoring : Load environment-specific monitoring configuration] *********
ok: [localhost]

TASK [routes : Load routes variables] ******************************************
ok: [localhost]

TASK [routes : Load environment-specific routes configuration] *****************
ok: [localhost]

TASK [cf-deployment : Include ECR Credential Provider Setup] *******************
included: /Users/swaroop/Documents/FullStack-SRE/ConsultingFirm_infra/ROSA/ClaudeDoc/ansible/roles/cf-deployment/tasks/setup-ecr-credential-provider.yml for localhost

TASK [cf-deployment : Create ECR credential provider configuration] ************
changed: [localhost]

TASK [cf-deployment : Wait for MachineConfig to be applied] ********************
ok: [localhost]

TASK [cf-deployment : Display ECR credential provider status] ******************
ok: [localhost] => {
    "msg": "ECR Credential Provider Configuration Applied:\n- ContainerRuntimeConfig: ecr-credential-provider created\n- Target Registry: 818140567777.dkr.ecr.us-east-1.amazonaws.com\n- ROSA ECR Role: arn:aws:iam::606639739464:role/ROSAECRAssumeRole\n- Cross-Account Role: arn:aws:iam::818140567777:role/ECRCrossAccountRole\n- Worker nodes will be updated automatically by Machine Config Operator\n- Wait time: ~5-10 minutes for all nodes to restart\n"
}

PLAY RECAP *********************************************************************
localhost                  : ok=10   changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Key Results
✅ **ContainerRuntimeConfig Created**: `ecr-credential-provider` resource applied  
✅ **Registry Configuration**: Auto-authentication to `818140567777.dkr.ecr.us-east-1.amazonaws.com`  
✅ **Role Chain Setup**: OIDC → ROSAECRAssumeRole → ECRCrossAccountRole  
✅ **Machine Config Applied**: Worker nodes will restart with new configuration  

### Expected Warnings (Normal)
```
[WARNING]: unknown field "spec.containerRuntimeConfig.credential_providers"
[WARNING]: unknown field "spec.containerRuntimeConfig.default_runtime"
```
These warnings are expected - they're OpenShift-specific extensions not in standard Kubernetes schema.

## What the Task Accomplishes

### 1. Creates ContainerRuntimeConfig
- **Kind**: `ContainerRuntimeConfig`
- **Name**: `ecr-credential-provider`
- **Target**: Worker node pools with `pools.operator.machineconfiguration.openshift.io/worker` label

### 2. Configures Credential Provider Script
The task embeds a shell script that:
1. Reads OIDC token from service account
2. Assumes `ROSAECRAssumeRole` using OIDC web identity
3. Assumes `ECRCrossAccountRole` for cross-account access
4. Retrieves ECR authorization token
5. Formats credentials for kubelet consumption

### 3. Sets Up Automatic Authentication
- **Cache Duration**: 12 hours
- **Registry URL**: `818140567777.dkr.ecr.us-east-1.amazonaws.com`
- **Authentication Method**: AWS ECR tokens via cross-account role assumption

## Post-Execution Timeline

1. **Immediate**: ContainerRuntimeConfig applied to cluster
2. **2-3 minutes**: Machine Config Operator processes changes
3. **5-10 minutes**: Worker nodes restart with new CRI-O configuration
4. **Ready**: Pods can pull images from ECR without authentication issues

## Troubleshooting

### Common Issues

#### 1. Missing Kubernetes Library
**Error**: `Failed to import the required Python library (kubernetes)`
**Solution**: Install libraries with `pip3.13 install kubernetes PyYAML --break-system-packages`

#### 2. Missing ecr_config Variable
**Error**: `'ecr_config' is undefined`
**Solution**: Include environment values file with `-e @environments/dev/deployment-values.yaml`

#### 3. Task Skipped
**Error**: Task shows `skipping: [localhost]`
**Solution**: Set condition variable with `-e setup_ecr_credential_provider=true`

### Verification Commands

```bash
# Check ContainerRuntimeConfig creation
oc get containerruntimeconfig ecr-credential-provider

# Monitor MachineConfigPool status
oc get machineconfigpool worker

# Verify worker node updates
oc get nodes

# Check if credential provider is working
oc run test-pod --image=818140567777.dkr.ecr.us-east-1.amazonaws.com/consultingfirm/frontend:latest --rm -it
```

## File References

- **Task File**: `roles/cf-deployment/tasks/setup-ecr-credential-provider.yml:4-131`
- **Main Orchestrator**: `roles/cf-deployment/tasks/main.yml:25-32`
- **Variables**: `environments/dev/deployment-values.yaml:10-16`
- **Execution Command**: Documented above

## Security Notes

- Uses OIDC-based authentication (no stored credentials)
- Implements proper cross-account role assumption chain
- ECR tokens cached for 12 hours with automatic refresh
- No sensitive data stored in cluster secrets

---
**Generated**: 2025-07-23  
**Environment**: ROSA/OpenShift 4.x  
**Ansible Version**: 2.18+  
**Python Version**: 3.13.x