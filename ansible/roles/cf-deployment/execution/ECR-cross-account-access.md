# ECR Cross-Account Access Setup for ROSA Cluster

## Overview
This guide provides step-by-step instructions to set up cross-account ECR access for a ROSA (Red Hat OpenShift Service on AWS) cluster. The setup enables pods in the OpenShift cluster to pull images from ECR repositories in a different AWS account using OIDC-based authentication.

## Architecture
- **OpenShift Cluster Account**: 606639739464 (where ROSA cluster runs)
- **ECR Registry Account**: 818140567777 (where container images are stored)
- **Authentication Method**: OIDC Web Identity with IAM roles
- **Continuous Token Refresh**: Automated ECR token refresh every 6 hours

## Prerequisites
1. ROSA cluster with STS (Security Token Service) enabled
2. AWS CLI access to the OpenShift cluster account (606639739464)
3. Proper OIDC provider configured for the ROSA cluster
4. `cf-dev` namespace created in OpenShift

## Files Created
All files are located in: `/environments/dev/`

1. **ecr-sa.yml** - ServiceAccount with OIDC annotation
2. **ecr-cross-account-policy.json** - IAM permissions policy for ECR access
3. **ecr-trust-policy.json** - IAM trust policy for OIDC authentication
4. **ecrsync.yml** - Deployment for continuous ECR token refresh

## Step-by-Step Implementation

### Step 1: Get ROSA Cluster Information

```bash
# List available ROSA clusters
rosa list clusters

# Get cluster OIDC endpoint (replace 'svktek-clstr-dev' with your cluster name)
rosa describe cluster --cluster=svktek-clstr-dev --output json | jq -r '.aws.sts.oidc_endpoint_url'
```

**Output Example:**
```
https://oidc.op1.openshiftapps.com/2k0c8r75om1ojie607vf4glkvbd4mo89
```

### Step 2: Verify Current AWS Account

```bash
# Confirm you're authenticated to the OpenShift cluster account
aws sts get-caller-identity
```

**Expected Output:**
```json
{
    "UserId": "AIDAY2PUL2JEFOBBYAC7L",
    "Account": "606639739464",
    "Arn": "arn:aws:iam::606639739464:user/svktek_admin"
}
```

### Step 3: Check Existing IAM Roles

```bash
# List existing ROSA/ECR related roles
aws iam list-roles --query 'Roles[?contains(RoleName, `ECR`) || contains(RoleName, `ROSA`)].{RoleName:RoleName,Arn:Arn}' --output table
```

### Step 4: Create ECR Cross-Account Permissions Policy

Create file: `environments/dev/ecr-cross-account-policy.json`

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage"
            ],
            "Resource": [
                "arn:aws:ecr:us-east-1:818140567777:repository/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken"
            ],
            "Resource": "*"
        }
    ]
}
```

### Step 5: Create OIDC Trust Policy

Create file: `environments/dev/ecr-trust-policy.json`

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::606639739464:oidc-provider/oidc.op1.openshiftapps.com/2k0c8r75om1ojie607vf4glkvbd4mo89"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.op1.openshiftapps.com/2k0c8r75om1ojie607vf4glkvbd4mo89:sub": "system:serviceaccount:cf-dev:ecr-sa",
                    "oidc.op1.openshiftapps.com/2k0c8r75om1ojie607vf4glkvbd4mo89:aud": "openshift"
                }
            }
        }
    ]
}
```

**Note**: Replace the OIDC provider URL with your cluster's actual OIDC endpoint.

### Step 6: Create IAM Role and Policies

```bash
# Create the IAM role with trust policy
aws iam create-role \
  --role-name ROSAECRAssumeRole \
  --assume-role-policy-document file://environments/dev/ecr-trust-policy.json

# Create the permissions policy
aws iam create-policy \
  --policy-name ROSAECRCrossAccountPolicy \
  --policy-document file://environments/dev/ecr-cross-account-policy.json

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name ROSAECRAssumeRole \
  --policy-arn arn:aws:iam::606639739464:policy/ROSAECRCrossAccountPolicy
```

### Step 7: Verify OIDC Provider Registration

```bash
# Check if OIDC provider is registered
aws iam list-open-id-connect-providers

# Verify role creation
aws iam get-role --role-name ROSAECRAssumeRole --query 'Role.AssumeRolePolicyDocument'
```

### Step 8: Create ServiceAccount

Create file: `environments/dev/ecr-sa.yml`

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::606639739464:role/ROSAECRAssumeRole
  name: ecr-sa
  namespace: cf-dev
```

Apply the ServiceAccount:

```bash
oc apply -f environments/dev/ecr-sa.yml
```

### Step 9: Create ECR Token Refresh Deployment

Create file: `environments/dev/ecrsync.yml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    app.kubernetes.io/owner: consultingFirm
    app.kubernetes.io/version: "1.0"
  labels:
    app.kubernetes.io/component: apiComponent
    app.kubernetes.io/instance: apiservice
    app.kubernetes.io/name: ecr-credentials-sync
    app.kubernetes.io/version: "1.0"
  name: ecr-credentials-sync
  namespace: cf-dev 
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: ecr-credentials-sync
  strategy:
    type: RollingUpdate
  template:
    metadata:
      annotations:
        app.kubernetes.io/owner: consultingFirm
        app.kubernetes.io/version: "1.0"
      labels:
        app: ecr-credentials-sync
        app.kubernetes.io/component: apiComponent
        app.kubernetes.io/instance: apiservice
        app.kubernetes.io/name: ecr-credentials-sync
        app.kubernetes.io/version: "1.0"
    spec:
      containers:
      - command:
        - /bin/sh
        - -ce
        - |-
          while true; do
            CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
            # ECR Initialization
            aws ecr get-login-password --region ${REGION} > /token/ecr-token

            # Command for create-secret
            oc create secret docker-registry regcred \
              --dry-run=client \
              --docker-server="818140567777.dkr.ecr.us-east-1.amazonaws.com" \
              --docker-username=AWS \
              --docker-password="$(cat /token/ecr-token)" \
              -o yaml | oc apply -f -

            echo "Successfully Secret Created at [$CURRENT_TIME]"

            sleep 6h
          done
        env:
        - name: REGION
          value: us-east-1
        image: amazon/aws-cli:latest
        imagePullPolicy: Always
        name: ecr-sync
        resources:
          limits:
            cpu: "1"
            memory: 2G
          requests:
            cpu: 500m
            memory: 1G
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
        - mountPath: /token
          name: token
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      securityContext: {}
      serviceAccount: ecr-sa
      serviceAccountName: ecr-sa
      terminationGracePeriodSeconds: 30
      volumes:
      - emptyDir:
          medium: Memory
        name: token
```

### Step 10: Deploy and Verify

```bash
# Apply the deployment
oc apply -f environments/dev/ecrsync.yml

# Check deployment status
oc get deployments -n cf-dev | grep ecr

# Check pod status
oc get pods -n cf-dev | grep ecr

# Verify secret creation
oc get secrets -n cf-dev | grep regcred

# Check logs
oc logs deployment/ecr-credentials-sync -n cf-dev
```

## Verification Commands

### Check OIDC Integration
```bash
# Verify ServiceAccount has proper annotations
oc describe serviceaccount ecr-sa -n cf-dev

# Check pod environment variables (should show AWS_ROLE_ARN and AWS_WEB_IDENTITY_TOKEN_FILE)
oc describe pod -n cf-dev -l app=ecr-credentials-sync
```

### Test ECR Access
```bash
# Exec into the pod and test AWS credentials
oc exec -it deployment/ecr-credentials-sync -n cf-dev -- aws sts get-caller-identity

# Test ECR login
oc exec -it deployment/ecr-credentials-sync -n cf-dev -- aws ecr get-login-password --region us-east-1
```

## Troubleshooting

### Common Issues

1. **CrashLoopBackOff with "Parameter validation failed: Invalid length for parameter RoleArn"**
   - Ensure the ServiceAccount has the correct role ARN annotation
   - Verify the role exists in AWS

2. **"Not authorized to perform sts:AssumeRoleWithWebIdentity"**
   - Check OIDC provider registration
   - Verify trust policy conditions match exactly
   - Ensure ServiceAccount name and namespace match the trust policy

3. **Pod Pending due to resource constraints**
   - Cluster autoscaler will add nodes automatically
   - Reduce resource requests if needed

4. **Image Pull Issues**
   - Ensure the base image (amazon/aws-cli:latest) is accessible
   - Check if additional tools (kubectl/oc) need to be installed in the container

### Debug Commands

```bash
# Check OIDC providers
aws iam list-open-id-connect-providers

# Verify role trust policy
aws iam get-role --role-name ROSAECRAssumeRole

# Check attached policies
aws iam list-attached-role-policies --role-name ROSAECRAssumeRole

# View pod events
oc describe pod -n cf-dev -l app=ecr-credentials-sync

# Check logs
oc logs -f deployment/ecr-credentials-sync -n cf-dev
```

## Security Considerations

1. **Least Privilege**: The IAM policy only grants necessary ECR permissions
2. **Scoped Trust**: Trust policy restricts access to specific ServiceAccount in specific namespace
3. **Token Rotation**: OIDC tokens are automatically rotated by OpenShift
4. **Secure Storage**: ECR tokens are stored in memory-backed volumes
5. **Time-Limited**: ECR tokens expire and are refreshed every 6 hours

## Integration with CF Deployment

This ECR access setup integrates with the cf-deployment Ansible role:

1. **Defaults**: ECR configuration is defined in `roles/cf-deployment/defaults/main.yml`
2. **Environment Overrides**: Environment-specific values in `environments/dev/deployment-values.yaml`
3. **Task Integration**: ECR token management is included via `roles/cf-deployment/tasks/ecr-token-management.yml`
4. **Orchestration**: Managed through `roles/cf-deployment/tasks/main.yml`

The `regcred` secret created by this deployment can be referenced in Helm charts using `imagePullSecrets` to enable automatic ECR image pulls for all CF microservices.

## Conclusion

This setup provides secure, automated ECR cross-account access for ROSA clusters using OIDC-based authentication. The continuous token refresh ensures uninterrupted access to ECR repositories, enabling reliable container image pulls for all deployed applications.