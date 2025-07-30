# Complete ECR Authentication Troubleshooting Walkthrough

## Initial Problem State

- Issue: All 16 CF microservice pods in ImagePullBackOff status
- Error: authentication required when pulling images from ECR
- Environment: cf-dev namespace on ROSA cluster

## Step 1: Initial Diagnosis - Root Cause Analysis

Command Executed:
```bash
kubectl describe pod naming-server-new-6f8fdc8875-gc6ch -n cf-dev
```

Key Error Found:
```
Failed to pull image "818140567777.dkr.ecr.us-east-1.amazonaws.com/consultingfirm/naming-server-service:latest":
authentication required
```

Analysis: This confirmed ECR authentication failure, not missing images or network issues.

## Step 2: Infrastructure Verification

Verified ECR Repository Exists:
```bash
aws ecr describe-repositories --profile sid-KS --region us-east-1 --repository-names consultingfirm/naming-server-service
```
Result: ✅ Repository exists in sidatks account (818140567777)

Verified Images Exist:
```bash
aws ecr list-images --profile sid-KS --region us-east-1 --repository-name consultingfirm/naming-server-service
```
Result: ✅ Images exist with latest tag, pushed on 2025-04-01T11:06:23

Verified Image Details:
```bash
aws ecr describe-images --profile sid-KS --region us-east-1 --repository-name consultingfirm/naming-server-service \
--image-ids imageTag=latest
```
Result: ✅ Image exists (211MB, SHA256: 7f35fc009219a1b...)

## Step 3: Cross-Account ECR Policy Verification

Initial Repository Policy Check:
```bash
aws ecr get-repository-policy --profile sid-KS --region us-east-1 --repository-name consultingfirm/naming-server-service
```

Initial Policy (PROBLEMATIC):
```json
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "CrossAccountPull",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::818140567777:role/ECRCrossAccountRole",
          "arn:aws:iam::606639739464:root"
        ]
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ]
    }
  ]
}
```

Problem Identified: Missing arn:aws:iam::606639739464:role/ROSAECRAssumeRole in the repository policy.

## Step 4: Service Account Configuration Analysis

Service Account Verification:
```bash
kubectl get serviceaccount ecr-sa -n cf-dev -o yaml
```

Service Account Configuration (CORRECT):
```yaml
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::606639739464:role/ROSAECRAssumeRole
  name: ecr-sa
  namespace: cf-dev
```

## Step 5: IAM Role Chain Analysis

ROSAECRAssumeRole Policy Check:
```bash
aws iam list-attached-role-policies --profile svktek --role-name ROSAECRAssumeRole
```

Initial Policies (MISSING ECR PERMISSIONS):
```json
{
  "AttachedPolicies": [
    {
      "PolicyName": "AssumeECRCrossAccountPolicy",
      "PolicyArn": "arn:aws:iam::606639739464:policy/AssumeECRCrossAccountPolicy"
    }
  ]
}
```

Trust Policy Verification:
```bash
aws iam get-role --profile svktek --role-name ROSAECRAssumeRole --query 'Role.AssumeRolePolicyDocument'
```

Trust Policy (CORRECT):
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
          "oidc.op1.openshiftapps.com/2k0c8r75om1ojie607vf4glkvbd4mo89:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

## Step 6: Root Cause Identification

Key Discovery: ROSAECRAssumeRole could assume ECRCrossAccountRole but had NO direct ECR permissions. Container runtimes need direct ECR access on the assumed role.

## Step 7: First Fix Attempt - Add ECR ReadOnly Policy

Policy Addition:
```bash
aws iam attach-role-policy --profile svktek --role-name ROSAECRAssumeRole --policy-arn \
arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

Verification:
```bash
aws iam list-attached-role-policies --profile svktek --role-name ROSAECRAssumeRole
```

Updated Policies:
```json
{
  "AttachedPolicies": [
    {
      "PolicyName": "AmazonEC2ContainerRegistryReadOnly",
      "PolicyArn": "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    },
    {
      "PolicyName": "AssumeECRCrossAccountPolicy",
      "PolicyArn": "arn:aws:iam::606639739464:policy/AssumeECRCrossAccountPolicy"
    }
  ]
}
```

ECR ReadOnly Policy Contents:
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
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
```

## Step 8: Test Pod Creation and Failure

Test Pod Manifest:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-ecr-access
  namespace: cf-dev
spec:
  serviceAccountName: ecr-sa
  containers:
  - name: test
    image: 818140567777.dkr.ecr.us-east-1.amazonaws.com/consultingfirm/naming-server-service:latest
    command: ["/bin/sh", "-c", "echo 'ECR test successful' && sleep 10"]
  restartPolicy: Never
```

Test Result: Still ImagePullBackOff with authentication required

## Step 9: Repository Policy Update Discovery

Problem Identified: ECR repository policy didn't include ROSAECRAssumeRole

Repository Policy Update:
```bash
aws ecr set-repository-policy --profile sid-KS --region us-east-1 --repository-name consultingfirm/naming-server-service \
--policy-text '{"Version":"2008-10-17","Statement":[{"Sid":"CrossAccountPull","Effect":"Allow","Principal":{"AWS":["arn:aws:iam::818140567777:role/ECRCrossAccountRole","arn:aws:iam::606639739464:root","arn:aws:iam::606639739464:role/ROSAECRAssumeRole"]},"Action":["ecr:GetDownloadUrlForLayer","ecr:BatchGetImage","ecr:BatchCheckLayerAvailability"]}]}'
```

Updated Repository Policy:
```json
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "CrossAccountPull",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::606639739464:role/ROSAECRAssumeRole",
          "arn:aws:iam::818140567777:role/ECRCrossAccountRole",
          "arn:aws:iam::606639739464:root"
        ]
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ]
    }
  ]
}
```

## Step 10: AWS CLI Test Pod Creation

Issue: Simple image pull still failing, need to test OIDC authentication directly

AWS CLI Test Pod (with proper security context for ROSA):
```bash
kubectl run aws-test --image=amazon/aws-cli:latest --overrides='{"spec":{"serviceAccountName":"ecr-sa","containers":[{"name":"aws-test","image":"amazon/aws-cli:latest","command":["sleep","300"],"securityContext":{"runAsNonRoot":true,"runAsUser":1000,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"seccompProfile":{"type":"RuntimeDefault"}}}]}}' -n cf-dev --restart=Never
```

Result: Pod successfully started (no image pull issues with public AWS CLI image)

## Step 11: OIDC Authentication Testing Inside Pod

Environment Variable Check:
```bash
kubectl exec aws-test -n cf-dev -- env | grep AWS
```

Results (PERFECT OIDC SETUP):
```
AWS_DEFAULT_REGION=us-east-1
AWS_REGION=us-east-1
AWS_ROLE_ARN=arn:aws:iam::606639739464:role/ROSAECRAssumeRole
AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
```

## Step 12: STS Identity Verification

STS Caller Identity Test:
```bash
kubectl exec aws-test -n cf-dev -- sh -c 'export HOME=/tmp && aws sts get-caller-identity'
```

Result (SUCCESS - OIDC WORKING):
```json
{
  "UserId": "AROAY2PUL2JEFAPPL7DFY:botocore-session-1753226219",
  "Account": "606639739464",
  "Arn": "arn:aws:sts::606639739464:assumed-role/ROSAECRAssumeRole/botocore-session-1753226219"
}
```

Key Discovery: OIDC authentication is working perfectly! Service account successfully assumes ROSAECRAssumeRole.

## Step 13: ECR Authorization Token Test

ECR Token Test:
```bash
kubectl exec aws-test -n cf-dev -- sh -c 'export HOME=/tmp && aws ecr get-authorization-token --region us-east-1'
```

Result (SUCCESS - ECR AUTHENTICATION WORKING):
```json
{
  "authorizationData": [
    {
      "authorizationToken": "QVdTOmV5SndZWGxzYjJGa0lqb2lRMlF2WjNGemJIQkZkVlkzVEhCeWFXcFVVaTgwWkZoQ09HRllhMk00TTFWaFpWTjVTa2wyUlVWNlZuWTVZaXRtVVRoUVFWSkVhMVpZVFdoVlREVnVUREo2VVdRNE9HZGtPWHBNUjAwM00yeGpVa3RwY0dGaFdXOXVOazFIYVZaV1lVZHhhbVV3WVdkMWN5OXpSVEZuTm5SVWQzUlBNWGxrYkVRM1V6aG9VbFY0UlZRMVJWTlpTMXBEU2tGWU1EVmFSVmt2VDBkVWVreGxaV3B2YVc5bGJYWnJaakpaWm1wQ1RrZGFiSEF6U3psa1UwVkhZakZyU1c5VVVsWkhSaTlKV1c1bmVFaHJSME5UVkhGQmRUY3hRMGQ1UXpReGRrMWxkRzh5T0dNMlJ6WjBielZaUTNSRlJrNDFVa3AxWTI5MmQxVkdXbFk1TTNOb2MyNDVjVTlxTTBsTldYRnliR0ZqYjFoRGRrVkdTbGwwU2l0UVJucG1Ramw0Ymk5alJXRTNXVFJhVlhodGRtMXVOVXhrWkdWbVExUnJhSEo0ZVdseVNuSjNVVWwyWTJORlpHbEVWUzlrYnpGVlZtNXplakYwTUdZMk56SnJjM0J5Vlc1bFdtcHpRWFl3UTB0RllVMVlhWEJRYlhOc05qbHZTRTUzTHpOUVRuRkhSREl3UlVOWlJXdDBaRnBYWjNaM09EYzRaVTg1T1RBdmJqbENLMmhhTW1oek5FWXdVRkoyYzNSSFEwdGFhVEl2V1d4VFYxSTBTRkJwVnpkQ1kyNVJjR2hvYWxNMlJtWjFUVUlyWmtsSWVtSkZWREZvU0ZSNU0yRTVhMDlFWlhSUVIxaEVSRFZPWmpkNWFISktZMUZKVWtJeVIwWjVkMXBqZDFsTVlsUjFNbVZxT1c1aVMxZFZOakEyYmpKQlZubDNlaXQzYW5wTlQzTnBPR2xKYW1KRFpsaDBORXc0WlZkeVEzcFpkMmhqYUZObVEwNU9UamR3V21OT1NsaHNTWEpPU2trMk1XTlVaSGxFTmxjdmVsUjZVMU4xZVZWYWF5dFZXRlZPUjNZMk9GbFlTSEp1VEhsUGJWTjRhRE5NZWtoRmNHNU1jalpKZFVaT1YyOW1XSEJ0ZHpoRVUzWm5VbFkwUkVNeFRqQnRkbFExUWtsU2FrMUpNbVJUUlZOaWJHSktVV2RRVTFaTVZqbElUWFZHWTNSRk9HcE9lVmxHYTAxbmNUWnlhbUZrTm01dGJWcFpSSGQwVjFCUFREaGhRMWh5Y1hKNk0yOWFjekJvWVhreWN6aHVPSEEzVHk5ak0wbDJjRGhQT1ZrdmNFOVpUbEZQV0hwa1ZuRkJkMWRPYW1SWVZGRmxZV3c0YUZOTVNVODVhelIxUkM5SU5EQTNWVzhyZHpGbE9EUTBXV2hHUzFCbWNtdE5MM00zZVhSUVRIRkxZbGcwUjIxRVp6UnJiUzlKWWxaTk9IbDRUVnBDUzFKT05WbHpTa3hUVGpKT1RuQlZWM0ZpWkhKdFoyVXhaM0p6T0Uwd2NsZFRjRzFMTVdORlJIRlBSMHRXY21oSVlURk1XV3d4ZDFSaFNWRklaMmQ1V1VWbmFtcGpiMGhPS3pSUk9HaHNPR055ZW1wVWVuQk1NVmgwYjAxblkyTTBlR0ZsV0d4eGJpOTNZaTlhU1hwM1RucGtTMkp0WnpjMmVFTkxXbEp2Ym5kSFlVbFpNa2RZVG5kUVRqVmlhMnh5ZW1jNFVsTnBSbEoxVTNwbVJ5OVZORlJZTVZCdFVUVnBTV2h2TUdWdlYzTnZLM3BwYlVaRGJDOTBRMmRTTm1OQlUxUnNNRFJ0VWtoWk4wY3hVRzVDVVRGNGRFNWFNWFZNTjBwaFNtMXZTRTFZWW5SMFZsaFRjakpNT0Zwb1pURktTMWhOU1V4S04zSlpaV2N3Tkc1UE5HNTVNM2cwTmxwTmNrUklOVFpTTVVGVEszcFVURWRzYURVdlMzSnJlamROVFhrNWNrSTRjSEZNYVVGdlJ6WkRSMUpOTm10M1NWZDJUV05EZW14VFUwdFdlVlZ6YWtrMVIyOW1Xa3RGY0dVd2JtVjJWRWg2VW05cmIzRkJPVXBFV1cxUlRFaEhRVmd2U1hSSk5EaFpNREo2TWpZMmJEVjBlbU14YlhSVVNIRXJNamQ1TWtwMmNUWTNOalJ4VTFaUWNXNUxSRk5KUTFvMWRVbzVabFJYV0M5MVVHbHRZbVZ2VUU5Q1VIRjRNREpqYmpoUWFYUmxlRUZaV0RoUU5UbElSVGhoUWpjM1NUbHZjVWhUWjFSemVuUjZNa1ZKY0RWcVNXUTBkV1JTYlhsMGVsTXdibmx2TDA5dVFpOUZNVU4zZVVsU1ZFWlBURmROUjA1QllrVndRa3AzV0hwRldqUmFRMnhpWjBkc1pXWmFTVkJ6TjBaNmVGWnZUa2R6VFhOUWFuaDBUREZZVjNSaGQxbGFValowV0N0QmMweE5kV2xIWkN0bk0zUnNSREVyYms4eWIyNXBkVE55UVVOUU5tcFRVMGROUzFBeFZHbHRNSFI1UzJ0RFVYTkZORmN4WjJGdGRFMWtVSEIyUjFka0wwRkdRMnhvV25vMGFXOVVNbTFZWVVKcVEzWmhOMGg2WjBGNmMwd3JiVEZNYzBOYU5UaFBPRmNyYUUxUE1FbHhSRlJDVFc5WVUwdGpZMjlCT1RSRFJsUlhlak56UlcxcmJ6UnNlR04xUkU1bk9FaERSRWxXU0hsdVIycG9Wa0ZZT0VaUGRERTBjRkJ4WVVsSmRFVlNhRGRXV1dkcE1qRkxWMkZvTWs5dGVqWXJZamhJZEVsc1NrRm1WVkp1ZW1GbVRqVldSbVZSYzBkSE1tWlphRFZOU3pWUmRUTjRiVE5PZGtkclNVeEdiMUZSYW5KSU5ITXZURU4zTWtwaFpIcE5ZWGg2UkdSVFpIY3dNV2wwUlNJc0ltUmhkR0ZyWlhraU9pSkJVVVZDUVVob2QyMHdXV0ZKVTBwbFVuUktiVFZ1TVVjMmRYRmxaV3RZZFc5WVdGQmxOVlZHWTJVNVVuRTRMekUwZDBGQlFVZzBkMlpCV1VwTGIxcEphSFpqVGtGUlkwZHZSemgzWWxGSlFrRkVRbTlDWjJ0eGFHdHBSemwzTUVKQ2QwVjNTR2RaU2xsSldrbEJWMVZFUWtGRmRVMUNSVVZFVGpoeFlXaGxZWE5KYUU5cFZuWndTRUZKUWtWSlFUY3ZTVFJhVkdSSlJWUmtla3RvVkd4T04zeDBNVWxDS3pWYU5scGhOR041U1ZsSGJsSlpSREk1T1V0clYwbEVVVmx4YmpSTVJFUllTMGhYTjFBelFYVjZOWEF2Tm1wa05sTjNkVGxQTDJOblBTSXNJblpsY25OcGIyNGlPaUl5SWl3aWRIbHdaU0k2SWtSQlZFRmZTMFZaSWl3aVpYaHdhWEpoZEdsdmJpSTZNVGMxTXpJMk9UUXpObjA9",
      "expiresAt": "2025-07-23T11:17:16.325000+00:00",
      "proxyEndpoint": "https://606639739464.dkr.ecr.us-east-1.amazonaws.com"
    }
  ]
}
```

## Key Findings & Current Status

### ✅ What's Working (CONFIRMED):

1. **OIDC Integration**: Service account successfully assumes ROSAECRAssumeRole
2. **IAM Policies**: ROSAECRAssumeRole has AmazonEC2ContainerRegistryReadOnly policy
3. **ECR Authorization**: Can get ECR authorization tokens from within pods
4. **Repository Access**: ECR repository policy includes ROSAECRAssumeRole
5. **Images Exist**: All container images are present in ECR with correct tags

### 🔍 Remaining Mystery:

Despite perfect authentication chain, container image pulls still fail with authentication required. This suggests:

1. **Container Runtime Issue**: CRI-O/Podman may not be properly using the OIDC token for cross-account ECR
2. **Token Timing**: Possible race condition between OIDC token refresh and image pull
3. **Registry Endpoint**: Container runtime might be hitting wrong ECR endpoint

### Current Test Environment:

- **aws-test pod**: ✅ Running with full ECR access via OIDC
- **test-ecr-access pod**: ❌ ImagePullBackOff with authentication error

### Next Investigation Steps:

1. Test manual docker/podman pull from within aws-test pod
2. Check CRI-O configuration for OIDC token handling
3. Verify registry endpoint resolution from container runtime
4. Test with a different ECR repository or image tag

This comprehensive analysis shows that all AWS IAM/OIDC components are working correctly, pointing to a container runtime-specific issue with cross-account ECR authentication.