# ROSA Load Balancer Controller - Concise Instructions

## Quick Deployment Commands

### Prerequisites Check
```bash
# 1. Verify ROSA cluster connection
oc whoami && oc get nodes

# 2. Check AWS CLI access
aws sts get-caller-identity

# 3. Get cluster OIDC issuer (required for IAM trust policy)
rosa describe cluster rosa-cluster-dev --output json | jq -r '.aws.sts.oidc_endpoint_url'
```

### Deploy Load Balancer Controller
```bash
# Execute Task 2 only (ALB Controller installation)
ansible-playbook playbooks/main.yml --tags alb-controller -e environment=dev
```

## Critical Dependencies Validation

### 1. ECR Authentication Flow
**Validation**: Pods must authenticate to ECR for image pull
- **Check**: IAM role exists with correct OIDC trust policy
- **Fix**: Trust policy must include complete OIDC issuer URL

```bash
# Check IAM role trust policy
aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole --query 'Role.AssumeRolePolicyDocument'

# Should contain: "arn:aws:iam::ACCOUNT:oidc-provider/oidc.c1.us-east-1.rosa.openshiftapps.com"
```

### 2. OpenShift Security Flow  
**Validation**: Deployment must comply with OpenShift SCCs
- **Check**: Security context configured as `runAsNonRoot: true`
- **Fix**: Container security context must not specify fixed UID

```bash
# Check deployment security context
oc get deployment aws-load-balancer-controller -n aws-load-balancer-controller -o yaml | grep -A 10 securityContext
```

### 3. Service Account RBAC
**Validation**: Service account must have ECR access via IAM role
- **Check**: ServiceAccount annotation matches IAM role ARN
- **Fix**: Role ARN must be: `arn:aws:iam::ACCOUNT:role/AmazonEKSLoadBalancerControllerRole`

```bash
# Check service account annotations
oc get serviceaccount aws-load-balancer-controller -n aws-load-balancer-controller -o yaml
```

## Common Failure Points & Quick Fixes

### Issue 1: ImagePullBackOff with "authentication required"
**Root Cause**: IAM role trust policy missing complete OIDC issuer URL
**Quick Fix**:
```bash
# Get OIDC issuer
OIDC_ISSUER=$(rosa describe cluster rosa-cluster-dev --output json | jq -r '.aws.sts.oidc_endpoint_url' | sed 's|https://||')

# Update IAM role trust policy
aws iam update-assume-role-policy --role-name AmazonEKSLoadBalancerControllerRole --policy-document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Federated": "arn:aws:iam::ACCOUNT:oidc-provider/'$OIDC_ISSUER'"},
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "'$OIDC_ISSUER':sub": "system:serviceaccount:aws-load-balancer-controller:aws-load-balancer-controller",
        "'$OIDC_ISSUER':aud": "openshift"
      }
    }
  }]
}'
```

### Issue 2: Deployment fails with SCC violations
**Root Cause**: OpenShift Security Context Constraints reject privileged containers
**Quick Fix**: Deployment already configured with `runAsNonRoot: true`

### Issue 3: Missing IAM permissions for ALB management
**Root Cause**: IAM role lacks ALB Controller policy
**Quick Fix**:
```bash
# Attach ALB Controller policy
aws iam attach-role-policy \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --policy-arn arn:aws:iam::ACCOUNT:policy/AWSLoadBalancerControllerIAMPolicy
```

## Validation Commands

### Post-Deployment Checks
```bash
# 1. Check deployment status
oc get deployment -n aws-load-balancer-controller

# 2. Check pod status
oc get pods -n aws-load-balancer-controller

# 3. Check controller logs
oc logs -n aws-load-balancer-controller deployment/aws-load-balancer-controller

# 4. Test ALB capability
oc get ingressclass alb
```

### Success Criteria
- [x] Deployment shows "2/2 Ready"
- [x] Pods show "Running" status (not ImagePullBackOff)
- [x] Controller logs show successful startup
- [x] IngressClass "alb" is available

## Environment Variables Required

```yaml
# /ansible/environments/dev/loadbalancer-config.yml
alb_configuration:
  alb_domain_name: "monitoring.rosa-dev.example.com"
  alb_load_balancer_name: "rosa-monitoring-alb"
  alb_scheme: "internet-facing"
  alb_target_type: "ip"
  alb_group_name: "rosa-monitoring"

controller_service_account: "aws-load-balancer-controller"
iam_policy_name: "AWSLoadBalancerControllerIAMPolicy"
```

## Next Steps After Successful Deployment

1. **Task 3**: Create ALB Ingress with path-based routing
2. **Task 4**: Convert LoadBalancer services to ClusterIP
3. **Task 5**: Test consolidated endpoints
4. **Task 6**: Configure DNS/SSL
5. **Task 7**: Cleanup old ELBs

## Cost Optimization Target
- **Current**: 2 separate ELB endpoints
- **Target**: 1 consolidated ALB with path-based routing
- **Expected Savings**: 67% reduction in load balancer costs