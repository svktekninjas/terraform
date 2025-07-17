# Task 2: AWS IAM Setup for Load Balancer Controller

## Overview
This task creates the necessary AWS IAM roles and policies for the two-tier load balancer architecture:
- **ALB**: Handles SSL termination and DNS routing
- **Nginx**: Handles path-based routing to services

## Architecture Design
```
Internet → Route53 → ALB (SSL + DNS) → Nginx DaemonSet (Path Routing) → Services
```

## Task File Location
`roles/rosa_loadbalancer/tasks/setup_aws_iam.yml`

## Execution Command
```bash
ansible-playbook playbooks/main.yml --tags "loadbalancer,config,iam,aws-setup" --skip-tags "consolidate,endpoints" -e target_environment=dev -e aws_profile=svktek
```

## Prerequisites
1. AWS CLI configured with svktek profile
2. Admin access to AWS account: 606639739464
3. ROSA cluster: svktek-clstr-dev
4. OIDC provider configured for cluster

## Components Created

### 1. IAM Policies
- **AWSLoadBalancerControllerIAMPolicy**: Standard AWS LB Controller permissions
- **ROSANginxNLBPolicy**: Additional NLB management permissions for Nginx

### 2. IAM Role
- **Name**: ROSANginxLoadBalancerRole
- **Purpose**: Allows Nginx pods to assume role for AWS operations
- **Trust Policy**: OIDC-based trust for service account `ingress-system:nginxlbsa`

### 3. OIDC Trust Policy
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
          "oidc.op1.openshiftapps.com/2k0c8r75om1ojie607vf4glkvbd4mo89:aud": "openshift",
          "oidc.op1.openshiftapps.com/2k0c8r75om1ojie607vf4glkvbd4mo89:sub": "system:serviceaccount:ingress-system:nginxlbsa"
        }
      }
    }
  ]
}
```

## Environment Variables Used
```yaml
# From environments/dev/loadbalancer-config.yml
aws_account_id: "606639739464"
oidc_issuer_url: "https://oidc.op1.openshiftapps.com/2k0c8r75om1ojie607vf4glkvbd4mo89"
cluster_name: "svktek-clstr-dev"
nginx_configuration:
  nginx_namespace: "ingress-system"
  nginx_service_account: "nginxlbsa"
  nginx_iam_role_name: "ROSANginxLoadBalancerRole"
  nginx_nlb_policy_name: "ROSANginxNLBPolicy"
```

## Execution Results
```
Task 2 - AWS IAM Setup Complete

Status: SUCCESS

Components Created:
- IAM Role: ROSANginxLoadBalancerRole
- Load Balancer Controller Policy: AWSLoadBalancerControllerIAMPolicy
- NLB Management Policy: ROSANginxNLBPolicy
- OIDC Trust Policy for service account authentication

Next Steps:
- Proceed to Task 3: OpenShift RBAC and SCC Setup
- Verify role permissions before Nginx deployment
```

## Verification Commands
```bash
# Check IAM role exists
aws iam get-role --role-name ROSANginxLoadBalancerRole

# Check attached policies
aws iam list-attached-role-policies --role-name ROSANginxLoadBalancerRole

# Check trust policy
aws iam get-role --role-name ROSANginxLoadBalancerRole --query 'Role.AssumeRolePolicyDocument'
```

## Troubleshooting

### Common Issues
1. **Policy Already Exists**: Ignore this error - it's expected if running multiple times
2. **Role Already Exists**: Ignore this error - it's expected if running multiple times
3. **OIDC Provider Not Found**: Ensure ROSA cluster is properly configured with STS

### Error Resolution
- **EntityAlreadyExists**: Normal behavior, task continues with `ignore_errors: yes`
- **Invalid OIDC Issuer**: Verify cluster OIDC URL in environment config
- **Access Denied**: Ensure AWS profile has admin permissions

## Security Considerations
- IAM role uses OIDC trust policy (no long-term credentials)
- Least privilege principle applied to policies
- Service account bound to specific namespace
- Trust policy restricted to specific OIDC conditions

## Next Task
Proceed to [Task 3: OpenShift RBAC and SCC Setup](task-3-openshift-rbac-setup.md)