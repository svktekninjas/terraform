# Task 6: Create NodePort Service for Nginx - Execution Document

## Overview
This document provides step-by-step execution instructions for creating a NodePort Service for the nginx load balancer in the ROSA cluster. The NodePort service exposes nginx pods to receive traffic from the AWS Application Load Balancer (ALB).

## Prerequisites
- Task 5 (Nginx DaemonSet) must be completed successfully
- nginx pods must be running in the monitoring namespace
- Environment-specific configuration file must be available
- OpenShift CLI (oc) access to the cluster
- Ansible playbook execution environment

## Architecture Context
```
Internet → Route53 → ALB (SSL/DNS) → NodePort Service → Nginx DaemonSet → Backend Services
                                     ↑ THIS TASK
```

## Task Components

### 1. Task File Location
- **File**: `/roles/rosa_loadbalancer/tasks/create_nodeport_service.yml`
- **Tags**: `[loadbalancer, nginx, nodeport, service]`
- **Dependencies**: nginx DaemonSet pods running

### 2. Configuration Dependencies
- **Config File**: `environments/dev/loadbalancer-config.yml`
- **Required Variables**:
  - `nginx_configuration.nginx_namespace`
  - `nginx_configuration.nginx_service_type`
  - `nginx_configuration.nginx_port`
  - `nginx_configuration.nginx_target_port`
  - `nginx_configuration.nginx_node_port`

## Execution Steps

### Step 1: Pre-Execution Validation
```bash
# Verify nginx pods are running
oc get pods -n monitoring -l app=nginx-loadbalancer

# Expected output: 2 running nginx pods
NAME                       READY   STATUS    RESTARTS   AGE
nginx-loadbalancer-xxx     1/1     Running   0          XXm
nginx-loadbalancer-yyy     1/1     Running   0          XXm
```

### Step 2: Execute NodePort Service Creation
```bash
# Navigate to ansible directory
cd /Users/swaroop/Documents/FullStack-SRE/ConsultingFirm_infra/ROSA/ClaudeDoc/ansible

# Execute with config file injection
ansible-playbook playbooks/main.yml \
  --tags "nodeport,service" \
  -e target_environment=dev \
  -e aws_profile=svktek \
  -e @environments/dev/loadbalancer-config.yml
```

### Step 3: Execution Verification
The playbook will execute the following tasks:
1. Create NodePort Service for nginx Load Balancer
2. Wait for NodePort Service to be ready
3. Get NodePort Service details
4. Test NodePort Service connectivity
5. Create execution summary
6. Extract service information for ALB configuration

## Expected Results

### Service Configuration
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-loadbalancer-nodeport
  namespace: monitoring
  labels:
    app: nginx-loadbalancer
    component: load-balancer
    tier: infrastructure
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/health"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "8080"
spec:
  type: NodePort
  ports:
  - name: http
    port: 80
    targetPort: 8080
    nodePort: 30080
    protocol: TCP
  selector:
    app: nginx-loadbalancer
  sessionAffinity: None
  externalTrafficPolicy: Local
```

### Key Service Details
- **Service Name**: `nginx-loadbalancer-nodeport`
- **Namespace**: `monitoring`
- **Type**: `NodePort`
- **Service Port**: `80`
- **Target Port**: `8080` (nginx container port)
- **NodePort**: `30080` (external access port)
- **External Traffic Policy**: `Local`
- **Health Check**: `/health` endpoint

### Service Information for ALB
```
NODEPORT_SERVICE_NAME=nginx-loadbalancer-nodeport
NODEPORT_NUMBER=30080
CLUSTER_IP=172.30.160.199
TARGET_PORT=8080
NAMESPACE=monitoring
```

## Validation Commands

### Service Status Check
```bash
# Check service status
oc get service nginx-loadbalancer-nodeport -n monitoring

# Check service details
oc describe service nginx-loadbalancer-nodeport -n monitoring

# Check service endpoints
oc get endpoints nginx-loadbalancer-nodeport -n monitoring
```

### Connectivity Testing
```bash
# Test health endpoint via cluster IP
curl -s http://172.30.160.199:80/health

# Test health endpoint via NodePort (from worker node)
curl -s http://WORKER_NODE_IP:30080/health
```

## Troubleshooting

### Common Issues

#### 1. Variable Loading Issues
**Problem**: `'nginx_configuration' is undefined`
**Solution**: Use config file injection approach:
```bash
-e @environments/dev/loadbalancer-config.yml
```

#### 2. Service Not Ready
**Problem**: Service creation timeout
**Solution**: Check nginx pod status:
```bash
oc get pods -n monitoring -l app=nginx-loadbalancer
oc describe pods -n monitoring -l app=nginx-loadbalancer
```

#### 3. Connectivity Test Failures
**Problem**: Health check failing
**Solution**: Check nginx configuration and endpoints:
```bash
# Check nginx configuration
oc get configmap nginx-config -n monitoring -o yaml

# Check nginx pod logs
oc logs -n monitoring -l app=nginx-loadbalancer

# Verify endpoints
oc get endpoints nginx-loadbalancer-nodeport -n monitoring
```

#### 4. NodePort Conflicts
**Problem**: NodePort 30080 already in use
**Solution**: Check for conflicting services:
```bash
oc get services --all-namespaces | grep 30080
```

### Configuration Validation
```bash
# Verify service selector matches nginx pods
oc get pods -n monitoring -l app=nginx-loadbalancer --show-labels

# Check service annotations for ALB integration
oc get service nginx-loadbalancer-nodeport -n monitoring -o yaml | grep annotations -A 10
```

## Success Criteria
- ✅ NodePort Service created successfully
- ✅ Service has correct port mappings (80 → 8080 → 30080)
- ✅ Service endpoints point to nginx pods
- ✅ Health check endpoint accessible
- ✅ Service properly labeled and annotated for ALB integration
- ✅ External traffic policy set to "Local"
- ✅ Service information extracted for ALB configuration

## Next Steps
After successful completion of Task 6:
1. **Task 7**: Create ALB Ingress for SSL/DNS termination
2. Use extracted service information for ALB target configuration
3. Configure ALB to route traffic to NodePort 30080

## Files Created/Modified
- **Service**: `nginx-loadbalancer-nodeport` in monitoring namespace
- **Summary**: `/tmp/nodeport_service_summary_[timestamp].txt`
- **Task File**: `create_nodeport_service.yml`

## Configuration Reference
Environment-specific settings used:
- **Environment**: `dev`
- **Cluster**: `svktek-clstr-dev`
- **Namespace**: `monitoring`
- **AWS Profile**: `svktek`
- **NodePort**: `30080`
- **Target Port**: `8080`

## Execution Timeline
- **Task Duration**: ~2-3 minutes
- **Service Creation**: ~30 seconds
- **Validation**: ~1 minute
- **Connectivity Tests**: ~30 seconds

## Notes
- The service uses `externalTrafficPolicy: Local` for better performance and source IP preservation
- Health check configured at `/health` endpoint on port 8080
- Service is annotated for NLB integration with cross-zone load balancing
- NodePort 30080 is exposed on all worker nodes for ALB access