# ROSA Load Balancer Role - Execution Documentation

## Overview
This directory contains detailed execution documentation for the ROSA Load Balancer role implementing a two-tier architecture:

```
Internet → Route53 → ALB (SSL + DNS) → Nginx DaemonSet (Path Routing) → Services
```

## Architecture Design

### Two-Tier Load Balancing
1. **Tier 1 - Application Load Balancer (ALB)**:
   - SSL termination (HTTPS → HTTP)
   - DNS/Route53 integration
   - Request forwarding to Nginx targets
   - Health checks for Nginx nodes

2. **Tier 2 - Nginx DaemonSet**:
   - Path-based routing (/prometheus, /grafana, /alertmanager)
   - Load balancing between service instances
   - Internal service discovery
   - High availability per worker node

### Benefits
- **SSL Offloading**: ALB handles SSL termination
- **Path Routing**: Nginx provides flexible path-based routing
- **High Availability**: DaemonSet ensures Nginx on every worker node
- **Cost Optimization**: Single ALB replaces multiple ELB endpoints
- **Performance**: Layer 4 + Layer 7 optimization

## Task Execution Order

### Phase 1: Foundation Setup
1. **[Task 1: Consolidate Endpoints](task-1-consolidate-endpoints.md)** ✅
   - Inventory existing LoadBalancer services and routes
   - Identify current ELB endpoints for optimization
   - Status: COMPLETED

2. **[Task 2: AWS IAM Setup](task-2-aws-iam-setup.md)** ✅
   - Create IAM roles and policies for Load Balancer Controller
   - Configure OIDC trust policy for service account
   - Status: COMPLETED

3. **[Task 3: OpenShift RBAC Setup](task-3-openshift-rbac-setup.md)** ⏳
   - Create namespace, service account, and RBAC
   - Configure Security Context Constraints (SCC)
   - Status: READY TO EXECUTE

### Phase 2: Load Balancer Infrastructure
4. **[Task 4: AWS Load Balancer Controller](task-4-alb-controller-install.md)** 🔄
   - Install and configure AWS Load Balancer Controller
   - Create webhook certificates and RBAC
   - Status: IN PROGRESS

5. **[Task 5: Nginx DaemonSet](task-5-nginx-daemonset.md)** 📋
   - Deploy Nginx DaemonSet per worker node
   - Configure path-based routing
   - Status: PENDING

6. **[Task 6: NodePort Service](task-6-nodeport-service.md)** 📋
   - Create NodePort service for Nginx
   - Configure health checks
   - Status: PENDING

### Phase 3: ALB Integration
7. **[Task 7: ALB Ingress](task-7-alb-ingress.md)** 📋
   - Create ALB Ingress for SSL/DNS termination
   - Configure target groups pointing to Nginx
   - Status: PENDING

8. **[Task 8: Route53 and ACM](task-8-route53-acm.md)** 📋
   - Configure Route53 DNS records
   - Setup ACM certificates for SSL
   - Status: PENDING

### Phase 4: Validation and Cleanup
9. **[Task 9: Security Policies](task-9-security-policies.md)** 📋
   - Configure network policies
   - Security hardening
   - Status: PENDING

10. **[Task 10: Testing and Validation](task-10-testing-validation.md)** 📋
    - End-to-end testing
    - Performance validation
    - Status: PENDING

11. **[Task 11: Cleanup and Monitoring](task-11-cleanup-monitoring.md)** 📋
    - Clean up old ELB endpoints
    - Setup monitoring and alerting
    - Status: PENDING

## Environment Configuration

### Development Environment
- **Cluster**: svktek-clstr-dev
- **AWS Account**: 606639739464
- **Region**: us-east-1
- **VPC**: vpc-0248cd16806a1b2da
- **Domain**: monitoring.svktek-dev.example.com

### Key Configuration Files
- `environments/dev/loadbalancer-config.yml` - Environment-specific configuration
- `environments/dev/cluster-config.yml` - Cluster configuration
- `environments/dev/monitoring-config.yml` - Monitoring configuration

## Execution Standards

### Prerequisites
1. **AWS CLI**: Configured with svktek profile
2. **OpenShift CLI**: Authenticated as cluster-admin
3. **Ansible**: Version 2.9+ with kubernetes.core collection
4. **Network Access**: To AWS APIs and OpenShift cluster

### Execution Pattern
```bash
# Standard execution command
ansible-playbook playbooks/main.yml --tags "loadbalancer,<specific-tags>" -e target_environment=dev -e aws_profile=svktek

# Example for specific task
ansible-playbook playbooks/main.yml --tags "loadbalancer,rbac,openshift,config" -e target_environment=dev
```

### Tags Structure
- `loadbalancer` - Main role tag
- `config` - Configuration loading
- `iam` - AWS IAM operations
- `rbac` - OpenShift RBAC operations
- `openshift` - OpenShift-specific operations
- `aws-setup` - AWS infrastructure setup
- `nginx` - Nginx-specific operations
- `alb-controller` - ALB Controller operations
- `ssl` - SSL/TLS operations
- `dns` - DNS operations

## Monitoring and Validation

### Health Checks
- AWS IAM role permissions
- OpenShift RBAC permissions
- ALB target group health
- Nginx pod readiness
- Service endpoint accessibility

### Validation Commands
```bash
# Check ALB status
aws elbv2 describe-load-balancers --names monitoring-alb-dev

# Check Nginx pods
oc get pods -n ingress-system -l app=nginx-loadbalancer

# Check service endpoints
curl -I http://monitoring.svktek-dev.example.com/prometheus
curl -I http://monitoring.svktek-dev.example.com/grafana
curl -I http://monitoring.svktek-dev.example.com/alertmanager
```

## Troubleshooting Guide

### Common Issues
1. **Authentication Errors**: Check AWS profile and OpenShift login
2. **Permission Denied**: Verify cluster-admin access
3. **Network Issues**: Check VPC and security group configuration
4. **DNS Resolution**: Verify Route53 configuration

### Debug Commands
```bash
# Check current context
oc config current-context
aws sts get-caller-identity --profile svktek

# Check role permissions
oc auth can-i create scc --as=system:serviceaccount:ingress-system:nginxlbsa

# Check ALB controller logs
oc logs -n aws-load-balancer-controller deployment/aws-load-balancer-controller
```

## Status Legend
- ✅ **COMPLETED**: Task successfully executed
- ⏳ **READY TO EXECUTE**: Prerequisites met, ready to run
- 🔄 **IN PROGRESS**: Currently being executed
- 📋 **PENDING**: Waiting for prerequisites
- ❌ **FAILED**: Execution failed, needs attention

## Next Steps
1. Execute Task 3: OpenShift RBAC Setup
2. Continue with remaining tasks in order
3. Update execution documentation as tasks complete
4. Create comprehensive validation test suite