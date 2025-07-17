# Task 3: OpenShift RBAC and SCC Setup

## Overview
This task creates OpenShift RBAC (Role-Based Access Control) and Security Context Constraints (SCC) for the Nginx load balancer in the two-tier architecture.

## Architecture Role
```
Internet → Route53 → ALB (SSL + DNS) → Nginx DaemonSet (Path Routing) → Services
                                         ↑
                                   RBAC + SCC Setup
```

## Task File Location
`roles/rosa_loadbalancer/tasks/setup_openshift_rbac.yml`

## Execution Command
```bash
ansible-playbook playbooks/main.yml --tags "loadbalancer,rbac,openshift,config" -e target_environment=dev
```

## Prerequisites
1. OpenShift CLI (oc) authenticated as cluster-admin
2. Target namespaces exist (monitoring, openshift-monitoring)
3. AWS IAM setup completed (Task 2)
4. Environment configuration loaded

## Components Created

### 1. Namespace
- **Name**: `ingress-system`
- **Purpose**: Dedicated namespace for load balancer infrastructure
- **Separation**: Follows namespace strategy (infrastructure vs application workloads)

### 2. Service Account
- **Name**: `nginxlbsa`
- **Namespace**: `ingress-system`
- **AWS Integration**: Annotated with IAM role ARN for OIDC authentication
- **Annotation**: `eks.amazonaws.com/role-arn: arn:aws:iam::606639739464:role/ROSANginxLoadBalancerRole`

### 3. ClusterRole
- **Name**: `nginx-loadbalancer-role`
- **Permissions**:
  - **Services/Endpoints/Pods**: Read access for service discovery
  - **Nodes**: Read access for node targeting
  - **ConfigMaps**: Full access for configuration management
  - **Ingresses**: Read access for ingress inspection
  - **Events**: Create/patch for event logging
  - **Leases**: Full access for leader election
  - **EndpointSlices**: Read access for modern service discovery

### 4. ClusterRoleBinding
- **Name**: `nginx-loadbalancer-binding`
- **Purpose**: Binds ClusterRole to ServiceAccount
- **Scope**: Cluster-wide permissions

### 5. Security Context Constraints (SCC)
- **Name**: `nginx-loadbalancer-scc`
- **Key Settings**:
  - `allowHostNetwork: true` - Required for NodePort binding
  - `allowHostPorts: true` - Required for port binding
  - `allowPrivilegedContainer: false` - Security best practice
  - `runAsUser: RunAsAny` - Flexibility for container execution
  - **Capabilities**: Drops dangerous capabilities (KILL, MKNOD, SETUID, SETGID)

### 6. Namespace-Specific Roles
- **monitoring**: nginx-monitoring-access role
- **openshift-monitoring**: nginx-openshift-monitoring-access role
- **Permissions**: Read-only access to services, endpoints, pods, configmaps, ingresses

### 7. RoleBindings
- **monitoring**: nginx-monitoring-binding
- **openshift-monitoring**: nginx-openshift-monitoring-binding
- **Purpose**: Cross-namespace access for service discovery

## Environment Variables Used
```yaml
# From environments/dev/loadbalancer-config.yml
nginx_configuration:
  nginx_namespace: "ingress-system"
  nginx_service_account: "nginxlbsa"
  nginx_iam_role_name: "ROSANginxLoadBalancerRole"

target_namespaces:
  - "monitoring"
  - "openshift-monitoring"

aws_account_id: "606639739464"
cluster_name: "svktek-clstr-dev"
```

## Execution Flow
1. **Create Namespace**: `ingress-system`
2. **Create Service Account**: With AWS IAM role annotation
3. **Create ClusterRole**: With required permissions
4. **Create ClusterRoleBinding**: Link role to service account
5. **Create SCC**: Security context constraints
6. **Create Namespace Roles**: For target namespaces
7. **Create RoleBindings**: Cross-namespace access
8. **Add SCC to Service Account**: Grant SCC permissions
9. **Verify Setup**: Comprehensive validation
10. **Generate Summary**: Execution summary and results

## Verification Commands
```bash
# Check namespace
oc get namespace ingress-system

# Check service account
oc get serviceaccount nginxlbsa -n ingress-system

# Check ClusterRole
oc get clusterrole nginx-loadbalancer-role

# Check ClusterRoleBinding
oc get clusterrolebinding nginx-loadbalancer-binding

# Check SCC
oc get scc nginx-loadbalancer-scc

# Check SCC assignment
oc describe scc nginx-loadbalancer-scc | grep ingress-system

# Check namespace roles
oc get role nginx-monitoring-access -n monitoring
oc get role nginx-openshift-monitoring-access -n openshift-monitoring

# Check role bindings
oc get rolebinding nginx-monitoring-binding -n monitoring
oc get rolebinding nginx-openshift-monitoring-binding -n openshift-monitoring
```

## Expected Output
```
Task 3 - OpenShift RBAC and SCC Setup Complete

Status: SUCCESS

Components Created:
- Namespace: ingress-system
- Service Account: nginxlbsa
- ClusterRole: nginx-loadbalancer-role
- ClusterRoleBinding: nginx-loadbalancer-binding
- Security Context Constraint: nginx-loadbalancer-scc
- Role bindings for target namespaces

Next Steps:
- Proceed to Task 4: AWS Load Balancer Controller Installation
- Service account ready for AWS IAM role association
```

## Security Considerations
- **Principle of Least Privilege**: Only necessary permissions granted
- **Namespace Isolation**: Clear separation between infrastructure and applications
- **SCC Restrictions**: Prevents privileged container execution
- **Cross-Namespace Access**: Limited to read-only service discovery
- **OIDC Integration**: Secure AWS integration without long-term credentials

## Troubleshooting

### Common Issues
1. **Namespace Already Exists**: Normal behavior, task continues
2. **SCC Assignment Failed**: Check service account exists first
3. **Role Binding Errors**: Verify target namespaces exist
4. **Permission Denied**: Ensure cluster-admin access

### Error Resolution
- **AlreadyExists**: Normal for idempotent operations
- **Forbidden**: Check current user permissions with `oc whoami`
- **NotFound**: Verify target namespaces exist
- **Invalid SCC**: Check SCC syntax and capabilities

## Next Task
Proceed to [Task 4: AWS Load Balancer Controller Installation](task-4-alb-controller-install.md)