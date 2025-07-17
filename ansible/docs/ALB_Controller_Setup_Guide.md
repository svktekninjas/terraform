# AWS Load Balancer Controller Setup Guide for ROSA

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Architecture Components](#architecture-components)
4. [Step-by-Step Implementation](#step-by-step-implementation)
5. [File Structure](#file-structure)
6. [Code Components Explained](#code-components-explained)
7. [Troubleshooting](#troubleshooting)
8. [Validation](#validation)

## Overview

This guide explains how to set up the AWS Load Balancer Controller (ALB Controller) in a ROSA (Red Hat OpenShift Service on AWS) cluster. The ALB Controller enables you to create Application Load Balancers (ALBs) directly from Kubernetes Ingress resources.

### What the ALB Controller Does:
- Manages AWS Application Load Balancers for Kubernetes Ingress resources
- Provides path-based routing for multiple services through a single ALB
- Reduces costs by consolidating multiple ELBs into one ALB
- Enables advanced AWS ALB features like SSL termination, WAF integration, etc.

### Cost Optimization:
- **Before**: Multiple LoadBalancer services = Multiple ELBs
- **After**: Single ALB with path-based routing = 67% cost reduction

## Prerequisites

### Required Tools:
- `ansible` - Infrastructure automation
- `oc` - OpenShift CLI
- `kubectl` - Kubernetes CLI
- `aws` - AWS CLI
- `rosa` - Red Hat OpenShift Service on AWS CLI

### Required Permissions:
- ROSA cluster admin access
- AWS IAM permissions for policy/role creation
- OpenShift cluster-admin privileges

### Environment Variables:
```yaml
aws_account_id: "606639739464"
vpc_id: "vpc-0248cd16806a1b2da"
aws_region: "us-east-1"
oidc_issuer_url: "https://oidc.op1.openshiftapps.com/2k0c8r75om1ojie607vf4glkvbd4mo89"
```

## Architecture Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWS Load Balancer Controller                 │
│                         Architecture                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│                     │    │                     │    │                     │
│   cert-manager      │    │   ALB Controller    │    │   AWS IAM Role      │
│   (Webhook Certs)   │───▶│   (Deployment)      │───▶│   (OIDC Trust)      │
│                     │    │                     │    │                     │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Resources                         │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐│
│  │  Service        │  │  ClusterRole    │  │  Ingress        ││
│  │  Account        │  │  & Binding      │  │  Class: alb     ││
│  └─────────────────┘  └─────────────────┘  └─────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Resources                            │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐│
│  │  Application    │  │  Target Groups  │  │  Security       ││
│  │  Load Balancer  │  │  (Auto-created) │  │  Groups         ││
│  └─────────────────┘  └─────────────────┘  └─────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Step-by-Step Implementation

### Step 1: Install cert-manager
**Purpose**: ALB Controller requires webhook certificates for secure communication.

**Location**: `roles/rosa_loadbalancer/tasks/install_alb_controller.yml:20-38`

```yaml
- name: "Install cert-manager for webhook certificates"
  shell: |
    kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.8.0/cert-manager.yaml
```

**Why cert-manager?**
- ALB Controller uses admission webhooks for validation
- Webhooks require TLS certificates for secure communication
- cert-manager automatically manages certificate lifecycle

### Step 2: Create IAM Policy
**Purpose**: Defines permissions ALB Controller needs to manage AWS resources.

**Location**: `roles/rosa_loadbalancer/tasks/install_alb_controller.yml:40-72`

```yaml
- name: "Download AWS Load Balancer Controller IAM policy"
  get_url:
    url: "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json"
    dest: "/tmp/iam_policy.json"

- name: "Create IAM policy for AWS Load Balancer Controller"
  shell: |
    aws iam create-policy \
      --policy-name AWSLoadBalancerControllerIAMPolicy \
      --policy-document file:///tmp/iam_policy.json
```

**IAM Policy Permissions Include:**
- `elasticloadbalancing:*` - Manage ALBs and target groups
- `ec2:DescribeVpcs` - VPC information
- `ec2:DescribeSubnets` - Subnet information
- `iam:CreateServiceLinkedRole` - Service-linked roles

### Step 3: Create IAM Role with OIDC Trust Policy
**Purpose**: Allows ALB Controller pods to assume AWS permissions via OIDC.

**Location**: `roles/rosa_loadbalancer/tasks/install_alb_controller.yml:74-122`

```yaml
- name: "Create IAM trust policy for ALB Controller"
  shell: |
    cat > /tmp/alb_trust_policy.json <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::{{ aws_account_id }}:oidc-provider/{{ oidc_issuer_url | replace('https://','') }}"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "{{ oidc_issuer_url | replace('https://','') }}:sub": "system:serviceaccount:aws-load-balancer-controller:aws-load-balancer-controller",
            "{{ oidc_issuer_url | replace('https://','') }}:aud": "openshift"
          }
        }
      }]
    }
    EOF
```

**OIDC Trust Policy Explanation:**
- **Federated**: Points to ROSA cluster's OIDC provider
- **Condition**: Restricts to specific service account
- **aud**: Must be "openshift" for ROSA clusters

### Step 4: Create RBAC Permissions
**Purpose**: Grant ALB Controller necessary Kubernetes permissions.

**Location**: `roles/rosa_loadbalancer/tasks/install_alb_controller.yml:124-184`

```yaml
- name: "Create ClusterRole for AWS Load Balancer Controller"
  kubernetes.core.k8s:
    definition:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: aws-load-balancer-controller
      rules:
      - apiGroups: [""]
        resources: ["services", "endpoints", "nodes", "pods"]
        verbs: ["get", "list", "watch"]
      - apiGroups: ["networking.k8s.io"]
        resources: ["ingresses"]
        verbs: ["get", "list", "watch", "update", "patch"]
```

**Key RBAC Permissions:**
- **services**: Monitor service changes
- **ingresses**: Manage Ingress resources
- **nodes**: Discover node information
- **targetgroupbindings**: Custom resource for ALB targets

### Step 5: Create Service Account
**Purpose**: Identity for ALB Controller pods with AWS role annotation.

**Location**: `roles/rosa_loadbalancer/tasks/install_alb_controller.yml:157-167`

```yaml
- name: "Create service account for AWS Load Balancer Controller"
  kubernetes.core.k8s:
    definition:
      apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: aws-load-balancer-controller
        namespace: aws-load-balancer-controller
        annotations:
          eks.amazonaws.com/role-arn: "arn:aws:iam::{{ aws_account_id }}:role/AmazonEKSLoadBalancerControllerRole"
```

**Service Account Annotation:**
- `eks.amazonaws.com/role-arn`: Links to IAM role for AWS permissions

### Step 6: Create Webhook Certificate Infrastructure
**Purpose**: Secure communication for admission webhooks.

**Location**: `roles/rosa_loadbalancer/tasks/install_alb_controller.yml:186-230`

```yaml
- name: "Create self-signed issuer for webhook certificates"
  kubernetes.core.k8s:
    definition:
      apiVersion: cert-manager.io/v1
      kind: Issuer
      metadata:
        name: aws-load-balancer-controller-selfsigned-issuer
        namespace: aws-load-balancer-controller
      spec:
        selfSigned: {}

- name: "Create webhook certificate for ALB Controller"
  kubernetes.core.k8s:
    definition:
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: aws-load-balancer-webhook-tls
        namespace: aws-load-balancer-controller
      spec:
        secretName: aws-load-balancer-webhook-tls
        dnsNames:
        - aws-load-balancer-webhook-service.aws-load-balancer-controller.svc
        - aws-load-balancer-webhook-service.aws-load-balancer-controller.svc.cluster.local
```

**Webhook Certificate Components:**
- **Issuer**: Creates self-signed certificates
- **Certificate**: Defines certificate details and DNS names
- **Service**: Exposes webhook endpoint on port 9443

### Step 7: Deploy ALB Controller
**Purpose**: Main controller deployment with proper configuration.

**Location**: `roles/rosa_loadbalancer/tasks/install_alb_controller.yml:232-312`

```yaml
- name: "Deploy AWS Load Balancer Controller"
  shell: |
    cat <<EOF | oc apply -f -
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: aws-load-balancer-controller
      namespace: aws-load-balancer-controller
    spec:
      replicas: 2
      selector:
        matchLabels:
          app.kubernetes.io/name: aws-load-balancer-controller
      template:
        spec:
          serviceAccountName: aws-load-balancer-controller
          securityContext:
            runAsNonRoot: true
          containers:
          - name: controller
            image: public.ecr.aws/eks/aws-load-balancer-controller:v2.7.2
            args:
            - --cluster-name=svktek-clstr-dev
            - --ingress-class=alb
            - --aws-region={{ aws_region }}
            - --aws-vpc-id={{ vpc_id }}
            volumeMounts:
            - name: webhook-certs
              mountPath: /tmp/k8s-webhook-server/serving-certs
              readOnly: true
          volumes:
          - name: webhook-certs
            secret:
              secretName: aws-load-balancer-webhook-tls
    EOF
```

**Deployment Configuration:**
- **Image**: Public ECR registry (no authentication needed)
- **replicas**: 2 for high availability
- **securityContext**: OpenShift security constraints
- **volumeMounts**: Webhook certificate access
- **args**: Cluster-specific configuration

## File Structure

```
ansible/
├── roles/rosa_loadbalancer/
│   ├── defaults/main.yml                     # Default variables
│   ├── tasks/
│   │   ├── main.yml                         # Main orchestration
│   │   └── install_alb_controller.yml       # ALB Controller installation
│   └── Execution/
│       └── task-2-install-alb-controller.md # Execution documentation
├── environments/dev/
│   └── loadbalancer-config.yml              # Environment-specific config
└── playbooks/
    └── main.yml                             # Main playbook
```

## Code Components Explained

### Environment Configuration
**File**: `environments/dev/loadbalancer-config.yml`

```yaml
# AWS Network Configuration
aws_account_id: "606639739464"
vpc_id: "vpc-0248cd16806a1b2da"
aws_region: "us-east-1"
oidc_issuer_url: "https://oidc.op1.openshiftapps.com/2k0c8r75om1ojie607vf4glkvbd4mo89"

# ALB Configuration
alb_configuration:
  alb_domain_name: "svktek-dev.rosa.example.com"
  alb_load_balancer_name: "monitoring-alb-dev"
  alb_scheme: "internet-facing"
  alb_target_type: "instance"
  alb_group_name: "monitoring-dev"
```

### Main Orchestration
**File**: `roles/rosa_loadbalancer/tasks/main.yml`

```yaml
- name: "Load environment-specific loadbalancer configuration"
  include_vars: "{{ playbook_dir }}/environments/{{ environment }}/loadbalancer-config.yml"

- name: "Validate/Install AWS Load Balancer Controller"
  include_tasks: install_alb_controller.yml
  tags: [loadbalancer, alb-controller, install]
```

### Execution Command
```bash
ansible-playbook playbooks/main.yml --tags alb-controller -e environment=dev \
  -e aws_account_id=606639739464 \
  -e oidc_issuer_url="https://oidc.op1.openshiftapps.com/2k0c8r75om1ojie607vf4glkvbd4mo89" \
  -e vpc_id=vpc-0248cd16806a1b2da \
  -e aws_region=us-east-1 \
  -e controller_service_account=aws-load-balancer-controller
```

## Troubleshooting

### Common Issues and Solutions

#### 1. ImagePullBackOff Error
**Symptom**: Pods fail to start with "authentication required"
**Cause**: Missing IAM role or incorrect OIDC trust policy
**Solution**: Verify OIDC issuer URL and IAM role trust policy

#### 2. CrashLoopBackOff with Exit Code 2
**Symptom**: Pods restart repeatedly
**Cause**: Invalid command arguments or missing webhook certificates
**Solution**: Check deployment arguments and ensure cert-manager is installed

#### 3. Webhook Certificate Errors
**Symptom**: "no such file or directory" for webhook certificates
**Cause**: Missing cert-manager or certificate not ready
**Solution**: Wait for cert-manager to generate certificates

#### 4. RBAC Permission Errors
**Symptom**: "configmaps is forbidden" errors
**Cause**: Insufficient RBAC permissions
**Solution**: Verify ClusterRole and ClusterRoleBinding are applied

### Debug Commands
```bash
# Check ALB Controller status
oc get pods -n aws-load-balancer-controller

# Check webhook certificates
oc get certificate -n aws-load-balancer-controller

# Check controller logs
oc logs -n aws-load-balancer-controller deployment/aws-load-balancer-controller

# Check IAM role
aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole

# Check RBAC
oc get clusterrole aws-load-balancer-controller
oc get clusterrolebinding aws-load-balancer-controller
```

## Validation

### Success Criteria
- ✅ cert-manager pods running (3/3)
- ✅ ALB Controller pods running (2/2)
- ✅ Webhook certificates ready
- ✅ No CrashLoopBackOff errors
- ✅ Controller logs show successful startup

### Validation Commands
```bash
# 1. Check cert-manager
oc get pods -n cert-manager
# Expected: 3 pods Running

# 2. Check ALB Controller
oc get pods -n aws-load-balancer-controller
# Expected: 2 pods Running

# 3. Check certificates
oc get certificate -n aws-load-balancer-controller
# Expected: aws-load-balancer-webhook-tls Ready=True

# 4. Check IngressClass
oc get ingressclass
# Expected: alb IngressClass available

# 5. Verify controller functionality
oc logs -n aws-load-balancer-controller deployment/aws-load-balancer-controller | grep -i "successfully"
```

### Post-Installation Verification
Create a test Ingress to verify ALB Controller functionality:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-alb-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-service
            port:
              number: 80
```

If the ALB Controller is working correctly, this Ingress should trigger the creation of an AWS Application Load Balancer.

## Next Steps

After successful ALB Controller installation:
1. **Task 3**: Create ALB Ingress with path-based routing
2. **Task 4**: Convert LoadBalancer services to ClusterIP
3. **Task 5**: Test and validate consolidated endpoints
4. **Task 6**: Configure DNS and SSL certificates
5. **Task 7**: Clean up old ELB resources

This completes the ALB Controller setup. The controller is now ready to manage AWS Application Load Balancers for your ROSA cluster, enabling cost-effective load balancing with advanced AWS features.