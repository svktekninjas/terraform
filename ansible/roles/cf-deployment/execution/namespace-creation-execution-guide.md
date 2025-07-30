# Namespace Creation - Execution Guide

## Overview
This guide documents the execution of namespace creation task with Helm compatibility labels and annotations to ensure seamless integration with Helm deployments.

## Task Purpose
Create the CF namespace (`cf-dev`) with required Helm metadata so that Helm can use the existing namespace without ownership conflicts.

## Prerequisites

### 1. ROSA Cluster Access
Ensure you are logged into the ROSA cluster:
```bash
oc login https://api.o0r9m0f2v7l3b1c.55n4.p1.openshiftapps.com:6443 --username cluster-admin --password Tek@1402SVKTek
```

### 2. Ansible Environment
Verify Ansible is configured and kubernetes.core collection is installed:
```bash
ansible --version
ansible-galaxy collection list | grep kubernetes.core
```

## Execution Steps

### Step 1: Execute Namespace Creation
```bash
cd /Users/swaroop/Documents/FullStack-SRE/ConsultingFirm_infra/ROSA/ClaudeDoc/terraform/ansible
ansible-playbook create-namespace.yml -e env=dev
```

### Step 2: Verify Namespace Creation
```bash
oc get namespace cf-dev -o yaml
```

Expected output should include:
- **Labels**: `app.kubernetes.io/managed-by: Helm`
- **Annotations**: 
  - `meta.helm.sh/release-name: cf-microservices`
  - `meta.helm.sh/release-namespace: cf-dev`

## Configuration Details

### Playbook Variables
- **target_namespace**: `cf-dev` (default, can be overridden with `cf_ns`)
- **helm_release_name**: `cf-microservices` (default, can be overridden with `helm_release`)

### Namespace Definition
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cf-dev
  labels:
    app.kubernetes.io/managed-by: Helm
    name: cf-dev
  annotations:
    meta.helm.sh/release-name: cf-microservices
    meta.helm.sh/release-namespace: cf-dev
```

## Updated Playbook Code

### File: `create-namespace.yml`

**Key Changes Made:**
1. **Added Helm Release Variable**: `helm_release_name` for flexibility
2. **Enhanced Namespace Definition**: Uses `definition` block instead of simple parameters
3. **Helm Compatibility Labels**: Added required `app.kubernetes.io/managed-by: Helm` label
4. **Helm Metadata Annotations**: Added release name and namespace annotations

**Complete Task Definition:**
```yaml
- name: Create namespace with Helm compatibility
  kubernetes.core.k8s:
    definition:
      apiVersion: v1
      kind: Namespace
      metadata:
        name: "{{ target_namespace }}"
        labels:
          app.kubernetes.io/managed-by: Helm
          name: "{{ target_namespace }}"
        annotations:
          meta.helm.sh/release-name: "{{ helm_release_name }}"
          meta.helm.sh/release-namespace: "{{ target_namespace }}"
    state: present
  tags:
    - namespace
    - cf-namespace
```

## Execution Results

### Successful Execution Output
```
PLAY [Create CF Namespace] *****************************************************

TASK [Create namespace with Helm compatibility] ********************************
changed: [localhost]

TASK [Verify namespace exists] *************************************************
ok: [localhost]

TASK [Display namespace status] ************************************************
ok: [localhost] => {
    "msg": "Namespace 'cf-dev' status: Active"
}

PLAY RECAP *********************************************************************
localhost                  : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Verification Commands
```bash
# Check namespace exists with correct labels
oc get namespace cf-dev --show-labels

# Verify Helm annotations
oc get namespace cf-dev -o jsonpath='{.metadata.annotations}'

# Full namespace YAML
oc get namespace cf-dev -o yaml
```

## Problem Solved

### Issue
Helm was unable to install releases into manually created namespaces due to missing ownership metadata:
```
Error: Unable to continue with install: Namespace "cf-dev" in namespace "" exists and cannot be imported into the current release: invalid ownership metadata; label validation error: missing key "app.kubernetes.io/managed-by": must be set to "Helm"
```

### Solution
Updated the namespace creation playbook to include:
1. **Helm Management Label**: `app.kubernetes.io/managed-by: Helm`
2. **Release Metadata**: Proper annotations for Helm release tracking
3. **Namespace Ownership**: Clear ownership metadata for Helm integration

## Benefits

### 1. Helm Compatibility
- Helm can use existing namespace without conflicts
- No manual label/annotation commands required
- Seamless integration with Helm deployments

### 2. Automation
- Single playbook handles namespace creation with all requirements
- Consistent namespace setup across environments
- Reusable for different release names

### 3. Best Practices
- Follows Kubernetes labeling conventions
- Maintains proper resource ownership
- Enables GitOps workflows

## Usage Variations

### Different Environment
```bash
ansible-playbook create-namespace.yml -e env=test -e cf_ns=cf-test
```

### Different Helm Release
```bash
ansible-playbook create-namespace.yml -e env=prod -e helm_release=cf-production
```

### Custom Namespace Name
```bash
ansible-playbook create-namespace.yml -e cf_ns=custom-namespace -e helm_release=custom-release
```

## Next Steps

After successful namespace creation:

1. **Deploy Service Account**: Run cross-account ECR setup to create `ecr-sa`
2. **Deploy Microservices**: Use Helm deployments with the prepared namespace
3. **Verify Integration**: Confirm Helm can manage resources in the namespace

## Troubleshooting

### Common Issues

#### 1. Namespace Already Exists Without Labels
```bash
# Check current labels
oc get namespace cf-dev --show-labels

# If missing Helm labels, delete and recreate
oc delete namespace cf-dev
ansible-playbook create-namespace.yml -e env=dev
```

#### 2. Permission Issues
```bash
# Verify cluster admin access
oc whoami
oc auth can-i create namespaces
```

#### 3. Ansible Collection Missing
```bash
# Install required collection
ansible-galaxy collection install kubernetes.core
```

## Maintenance

### Regular Tasks
- Verify namespace labels remain intact after cluster operations
- Monitor namespace resource quotas and limits
- Review namespace annotations during Helm upgrades

### Updates
- Update helm_release_name when changing Helm release names
- Adjust target_namespace for new environments
- Keep playbook synchronized with Helm requirements

## Security Considerations

### RBAC
- Ensure proper service account permissions in the namespace
- Verify network policies don't block required traffic
- Monitor resource usage and quotas

### Labels and Annotations
- Maintain consistency in labeling strategy
- Document any custom labels added to namespace
- Validate Helm metadata integrity during deployments