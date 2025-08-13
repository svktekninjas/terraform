# ECR Cross-Account Access Setup Guide

## 🎯 **Objective**
Configure cross-account ECR access so ROSA cluster in `svktek` account can pull images from ECR repositories in `sidatks` account.

## 🏗️ **Architecture Overview**

```
┌─────────────────────────────────┐    Cross-Account    ┌─────────────────────────────────┐
│         sidatks Account         │    AssumeRole       │         svktek Account          │
│         (Source ECR)            │◄────────────────────│       (ROSA Cluster)           │
│                                 │                     │                                 │
│  ┌─────────────────────────────┐│                     │ ┌─────────────────────────────┐ │
│  │ ECR Repositories            ││                     │ │ ROSA Cluster (cf-dev)       │ │
│  │ - consultingfirm/naming-*   ││                     │ │ - Pulls images              │ │
│  │ - consultingfirm/api-*      ││                     │ │ - Uses cross-account secret │ │
│  │ - consultingfirm/config-*   ││                     │ │ - Service account access    │ │
│  │ - consultingfirm/*-service  ││                     │ └─────────────────────────────┘ │
│  └─────────────────────────────┘│                     │                                 │
│                                 │                     │ ┌─────────────────────────────┐ │
│  ┌─────────────────────────────┐│                     │ │ ECR Cross-Account IAM       │ │
│  │ ECRCrossAccountAdmin Role   ││                     │ │ - Assume role policy        │ │
│  │ - Assumable by svktek       ││                     │ │ - ECR pull permissions      │ │
│  │ - ECR management permissions││                     │ │ - Temporary credentials     │ │
│  │ - External ID protection    ││                     │ └─────────────────────────────┘ │
│  └─────────────────────────────┘│                     │                                 │
└─────────────────────────────────┘                     └─────────────────────────────────┘
```

## 📋 **Prerequisites**

### 1. **Manual Setup in sidatks Account** (One-time)

**⚠️ Important**: You need to create the cross-account admin role in the `sidatks` account first.

#### Option A: Using AWS Console (Recommended)
1. Login to `sidatks` AWS Console
2. Go to IAM → Roles → Create Role
3. Select "Another AWS Account"
4. Enter Account ID: `606639739464` (svktek account)
5. Check "Require external ID" and enter: `cf-ecr-cross-account-dev-2025`
6. Attach policy: `AmazonEC2ContainerRegistryFullAccess`
7. Name the role: `ECRCrossAccountAdmin`

#### Option B: Using AWS CLI (if you have sidatks CLI access)
```bash
# Create trust policy file
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::606639739464:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "cf-ecr-cross-account-dev-2025"
        }
      }
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name ECRCrossAccountAdmin \
  --assume-role-policy-document file://trust-policy.json

# Attach ECR permissions
aws iam attach-role-policy \
  --role-name ECRCrossAccountAdmin \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess

# Note the role ARN (you'll need the sidatks account ID)
aws iam get-role --role-name ECRCrossAccountAdmin --query 'Role.Arn'
```

### 2. **Update Configuration Files**

Update the `sidatks` account ID in the configuration:

```bash
# Edit the environment configuration
nano environments/dev/ecr-cross-account.yml

# Replace REPLACE_WITH_SIDATKS_ACCOUNT_ID with actual sidatks account ID
# Example: 123456789012
```

## 🚀 **Execution Steps**

### **Step 1: Configure Cross-Account Access**
```bash
# Navigate to ansible directory
cd /Users/swaroop/Documents/FullStack-SRE/ConsultingFirm_infra/ROSA/ClaudeDoc/terraform/ansible

# Run cross-account ECR setup
ansible-playbook playbooks/ecr-cross-account.yml -e env=dev -v
```

**What this does:**
1. ✅ Assumes the `ECRCrossAccountAdmin` role in sidatks account
2. ✅ Updates ECR repository policies to allow svktek account access
3. ✅ Creates IAM policy in svktek account for ECR cross-account access
4. ✅ Gets fresh ECR authorization token for cross-account registry
5. ✅ Creates/updates Docker registry secret in ROSA cluster
6. ✅ Updates service account to use the new secret
7. ✅ Verifies cross-account access by test pulling an image

### **Step 2: Verify Cross-Account Access**
```bash
# Verify the setup works
ansible-playbook playbooks/ecr-cross-account.yml --tags "verify" -e env=dev -v
```

### **Step 3: Update Microservice Deployments**
```bash
# Now deploy microservices with cross-account ECR access
ansible-playbook playbooks/main.yml --tags "cf-naming-server" -e env=dev -e deploy_naming_server_only=true -v
```

## 🔧 **Manual Verification Commands**

### **Check Secret in ROSA**
```bash
# Verify secret exists
oc get secret ecr-cross-account-secret -n cf-dev

# Check secret data
oc get secret ecr-cross-account-secret -n cf-dev -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq
```

### **Test Cross-Account Pull**
```bash
# Test pulling image directly
oc run test-pull \
  --image="SIDATKS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/consultingfirm/naming-server-service:latest" \
  --namespace=cf-dev \
  --restart=Never \
  --rm \
  --command -- /bin/sh -c "echo 'Cross-account pull successful'"
```

### **Check ECR Permissions**
```bash
# Test ECR authorization
aws ecr get-authorization-token \
  --registry-ids SIDATKS_ACCOUNT_ID \
  --region us-east-1 \
  --profile svktek
```

## 🛡️ **Security Features**

### **1. External ID Protection**
- Prevents confused deputy attacks
- Unique identifier: `cf-ecr-cross-account-dev-2025`
- Must be provided when assuming role

### **2. Least Privilege Access**
- Cross-account role only has ECR permissions
- No access to other AWS services
- Time-limited credentials (1 hour sessions)

### **3. Audit Trail**
- All cross-account access logged in CloudTrail
- Role assumption events tracked
- ECR access events monitored

## 🔍 **Troubleshooting**

### **Common Issues**

#### **1. "AccessDenied" when assuming role**
```bash
# Check if role exists and trust policy is correct
aws iam get-role --role-name ECRCrossAccountAdmin --profile sidatks

# Verify external ID matches
grep -r "external_id" environments/dev/ecr-cross-account.yml
```

#### **2. "Repository does not exist" errors**
```bash
# List ECR repositories in sidatks account
aws ecr describe-repositories --profile sidatks --region us-east-1

# Check repository naming convention
aws ecr describe-repositories --profile sidatks --region us-east-1 --query 'repositories[].repositoryName'
```

#### **3. "ImagePullBackOff" in ROSA**
```bash
# Check secret is attached to service account
oc get serviceaccount default -n cf-dev -o yaml

# Verify secret format
oc get secret ecr-cross-account-secret -n cf-dev -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq '.auths'

# Test manual image pull
docker login SIDATKS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

## 📝 **Configuration Reference**

### **Key Files**
- `roles/ecr-cross-account/` - Main role implementation
- `environments/dev/ecr-cross-account.yml` - Environment configuration
- `playbooks/ecr-cross-account.yml` - Execution playbook

### **Important Variables**
```yaml
cross_account:
  source_account_id: "SIDATKS_ACCOUNT_ID"     # Update this!
  target_account_id: "606639739464"           # svktek account
  external_id: "cf-ecr-cross-account-dev-2025"
  admin_role_name: "ECRCrossAccountAdmin"

rosa_config:
  namespace: "cf-dev"
  secret_name: "ecr-cross-account-secret"
```

## ✅ **Success Criteria**

After successful setup, you should see:

1. ✅ **Cross-account role assumption successful**
2. ✅ **ECR repository policies updated for 10 repositories**
3. ✅ **IAM policy created in svktek account**
4. ✅ **Docker registry secret created in cf-dev namespace**
5. ✅ **Service account updated with imagePullSecrets**
6. ✅ **Test image pull successful**

## 🎯 **Next Steps**

Once cross-account access is configured:

```bash
# Deploy all microservices
ansible-playbook playbooks/main.yml --tags "cf-deploy-all" -e env=dev -v

# Or deploy individual services
ansible-playbook playbooks/main.yml --tags "cf-naming-server" -e env=dev -e deploy_naming_server_only=true -v
ansible-playbook playbooks/main.yml --tags "cf-api-gateway" -e env=dev -e deploy_api_gateway_only=true -v
```

The ImagePullBackOff errors should be resolved, and pods should start successfully with access to the cross-account ECR repositories.