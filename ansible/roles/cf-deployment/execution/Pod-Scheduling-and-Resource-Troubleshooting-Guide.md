# Pod Scheduling and Resource Troubleshooting Guide for ROSA Clusters

## Overview
This guide explains how to identify resource contention, understand pod scheduling failures, and troubleshoot cluster scaling issues in ROSA (Red Hat OpenShift Service on AWS) clusters.

## How Resource Contention Was Identified

### 1. Pod Status Analysis
The initial indicator was the pod status showing `Pending`:

```bash
# Command used to identify the issue
oc get pods -n cf-dev | grep ecr

# Output showed:
ecr-credentials-sync-69db98b46-cxxwv        0/1     Pending            0          16s
```

**Key Indicator**: `Pending` status means the pod cannot be scheduled on any available node.

### 2. Pod Events Analysis
The definitive diagnosis came from examining pod events:

```bash
# Command to get detailed pod information and events
oc describe pod ecr-credentials-sync-69db98b46-cxxwv -n cf-dev
```

**Critical Output Section - Events**:
```
Events:
  Type     Reason            Age   From                Message
  ----     ------            ----  ----                -------
  Warning  FailedScheduling  30s   default-scheduler   0/7 nodes are available: 2 Insufficient cpu, 2 node(s) had untolerated taint {node-role.kubernetes.io/infra: }, 3 node(s) had untolerated taint {node-role.kubernetes.io/master: }. preemption: 0/7 nodes are available: 2 No preemption victims found for incoming pod, 5 Preemption is not helpful for scheduling.
  Normal   TriggeredScaleUp  27s   cluster-autoscaler  pod triggered scale-up: [{MachineSet/openshift-machine-api/o0r9m0f2v7l3b1c-mjpfj-worker-us-east-1a 2->3 (max: 4)}]
```

### 3. Event Analysis Breakdown

#### FailedScheduling Event Analysis:
- **`0/7 nodes are available`**: Total of 7 nodes in cluster, none can accommodate the pod
- **`2 Insufficient cpu`**: 2 worker nodes don't have enough CPU resources
- **`2 node(s) had untolerated taint {node-role.kubernetes.io/infra: }`**: 2 infrastructure nodes (not for workloads)
- **`3 node(s) had untolerated taint {node-role.kubernetes.io/master: }`**: 3 master nodes (not for workloads)
- **`2 No preemption victims found`**: Cannot evict other pods to make room
- **`5 Preemption is not helpful`**: Evicting pods won't solve the resource issue

#### TriggeredScaleUp Event Analysis:
- **`cluster-autoscaler`**: Shows autoscaler is active and responding
- **`pod triggered scale-up`**: This specific pod caused the scaling event
- **`MachineSet/...worker-us-east-1a 2->3 (max: 4)`**: Scaling from 2 to 3 nodes, max capacity is 4

## Pod Resource Requirements Analysis

### Resource Requests from Pod Spec:
```yaml
resources:
  limits:
    cpu: "1"        # 1 full CPU core
    memory: 2G      # 2 GB RAM
  requests:
    cpu: 500m       # 0.5 CPU core requested
    memory: 1G      # 1 GB RAM requested
```

The scheduler uses **requests** (not limits) for scheduling decisions.

## Detailed Troubleshooting Commands

### 1. Node Resource Analysis
```bash
# Check node resource utilization
oc describe nodes

# Get node resource summary
oc top nodes

# Check allocatable resources per node
oc get nodes -o custom-columns=NAME:.metadata.name,ALLOCATABLE-CPU:.status.allocatable.cpu,ALLOCATABLE-MEMORY:.status.allocatable.memory
```

**Example Output Analysis**:
```bash
NAME                                        ALLOCATABLE-CPU   ALLOCATABLE-MEMORY
ip-10-0-1-100.us-east-1.compute.internal    1930m            7474148Ki
ip-10-0-1-200.us-east-1.compute.internal    1930m            7474148Ki
```

**Analysis**: 
- Each worker node has ~1.93 CPU cores allocatable
- Pod requests 500m (0.5 cores), but existing workloads consumed remaining capacity

### 2. Pod Resource Analysis
```bash
# Check pod resource requests and limits
oc describe pod <pod-name> -n <namespace>

# Get resource usage of running pods
oc top pods -n <namespace>

# Check pod resource requests across all namespaces
oc get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU-REQUEST:.spec.containers[*].resources.requests.cpu,MEMORY-REQUEST:.spec.containers[*].resources.requests.memory
```

### 3. Scheduler Analysis
```bash
# Check scheduler events
oc get events --field-selector reason=FailedScheduling --all-namespaces

# Check scheduler logs (if accessible)
oc logs -n openshift-kube-scheduler -l app=openshift-kube-scheduler

# View scheduler configuration
oc get schedulers.operator.openshift.io cluster -o yaml
```

### 4. Cluster Autoscaler Analysis
```bash
# Check cluster autoscaler status
oc get clusterautoscaler

# Check machine autoscaler configuration
oc get machineautoscaler -n openshift-machine-api

# Check machine sets and their scaling limits
oc get machinesets -n openshift-machine-api

# View autoscaler events
oc get events -n openshift-machine-api --field-selector reason=TriggeredScaleUp
```

**Example MachineSet Output**:
```bash
NAME                                        DESIRED   CURRENT   READY   AVAILABLE   AGE
o0r9m0f2v7l3b1c-mjpfj-worker-us-east-1a   3         2         2       2           5d
```

## How Pod Scheduler Determines Resource Availability

### 1. Scheduling Algorithm
The Kubernetes scheduler uses a two-phase process:

#### Phase 1: Filtering (Predicates)
```bash
# The scheduler checks each node against predicates:
1. NodeResourcesFit - Does node have enough CPU/memory?
2. NodeAffinity - Does pod's nodeSelector match?
3. PodFitsHostPorts - Are required ports available?
4. NoDiskConflict - Are required volumes available?
5. NoVolumeZoneConflict - Volume zone constraints
6. PodToleratesNodeTaints - Can pod tolerate node taints?
```

#### Phase 2: Scoring (Priorities)
```bash
# Remaining nodes are scored based on:
1. NodeResourcesFitPriority - Prefer nodes with more available resources
2. BalancedResourceAllocation - Balance CPU and memory usage
3. NodeAffinityPriority - Prefer nodes matching affinity rules
4. InterPodAffinityPriority - Co-locate or separate pods as requested
```

### 2. Resource Calculation Formula
```bash
# Allocatable Resources = Node Capacity - System Reserved - Kube Reserved - Eviction Threshold

# Example for a node:
Node Capacity:      2 CPU cores, 8Gi memory
System Reserved:    100m CPU, 500Mi memory  (OS overhead)
Kube Reserved:      60m CPU, 500Mi memory   (kubelet, etc.)
Eviction Threshold: 10m CPU, 750Mi memory  (emergency buffer)
Allocatable:        1830m CPU, 6750Mi memory
```

### 3. Pod Fit Calculation
```bash
# For our ECR pod:
Pod CPU Request:    500m
Pod Memory Request: 1Gi

# Node must have:
Available CPU:    >= 500m
Available Memory: >= 1Gi

# If ANY node fails this check, pod shows "Insufficient cpu" or "Insufficient memory"
```

## Cluster Autoscaler Configuration Files

### 1. ClusterAutoscaler Resource
```bash
# Check current autoscaler configuration
oc get clusterautoscaler cluster -o yaml
```

**Example Configuration**:
```yaml
apiVersion: autoscaling.openshift.io/v1
kind: ClusterAutoscaler
metadata:
  name: default
spec:
  podPriorityThreshold: -10
  resourceLimits:
    maxNodesTotal: 24
    cores:
      min: 8
      max: 128
    memory:
      min: 4
      max: 256
  scaleDown:
    enabled: true
    delayAfterAdd: 10m
    delayAfterDelete: 10s
    delayAfterFailure: 30s
    unneededTime: 60s
```

### 2. MachineAutoscaler Resources
```bash
# Check machine autoscaler for each availability zone
oc get machineautoscaler -n openshift-machine-api -o yaml
```

**Example Configuration**:
```yaml
apiVersion: autoscaling.openshift.io/v1beta1
kind: MachineAutoscaler
metadata:
  name: worker-us-east-1a
  namespace: openshift-machine-api
spec:
  minReplicas: 1
  maxReplicas: 4
  scaleTargetRef:
    apiVersion: machine.openshift.io/v1beta1
    kind: MachineSet
    name: o0r9m0f2v7l3b1c-mjpfj-worker-us-east-1a
```

### 3. MachineSet Configuration
```bash
# Check the actual machine set that gets scaled
oc get machineset -n openshift-machine-api -o yaml
```

**Key Fields for Scaling**:
```yaml
spec:
  replicas: 3  # Current desired count
  template:
    spec:
      providerSpec:
        value:
          instanceType: m5.xlarge  # Node size
          placement:
            availabilityZone: us-east-1a
```

## How Cluster Scaling Works

### 1. Scale-Up Trigger Process
```
1. Pod created with resource requests
2. Scheduler attempts to place pod on existing nodes
3. All nodes fail resource fit check
4. Scheduler marks pod as "Pending" with FailedScheduling event
5. Cluster Autoscaler detects unschedulable pod
6. Autoscaler calculates resource requirements
7. Autoscaler selects appropriate node group (MachineSet)
8. Autoscaler increases MachineSet replica count
9. MachineSet creates new Machine resource
10. Machine controller provisions EC2 instance
11. New node joins cluster and registers with scheduler
12. Scheduler places pending pod on new node
```

### 2. Scale-Down Process
```
1. Autoscaler periodically checks node utilization
2. Identifies nodes below utilization threshold
3. Simulates pod eviction to ensure they can be scheduled elsewhere
4. Cordons node (prevents new pods)
5. Drains node (evicts existing pods)
6. Deletes Machine resource
7. EC2 instance is terminated
```

## Advanced Troubleshooting Commands

### 1. Resource Quota Analysis
```bash
# Check if namespace has resource quotas limiting pod creation
oc get resourcequota -n cf-dev
oc describe resourcequota -n cf-dev

# Check limit ranges that might affect pod resources
oc get limitrange -n cf-dev
```

### 2. Node Selector and Affinity Issues
```bash
# Check if pod has nodeSelector that limits scheduling
oc get pod <pod-name> -n <namespace> -o yaml | grep -A 10 nodeSelector

# Check node labels
oc get nodes --show-labels

# Check pod affinity/anti-affinity rules
oc get pod <pod-name> -n <namespace> -o yaml | grep -A 20 affinity
```

### 3. Taint and Toleration Analysis
```bash
# Check node taints
oc describe node <node-name> | grep Taints

# Check pod tolerations
oc get pod <pod-name> -n <namespace> -o yaml | grep -A 10 tolerations
```

### 4. Priority and Preemption
```bash
# Check pod priority class
oc get pod <pod-name> -n <namespace> -o yaml | grep priorityClassName

# List priority classes
oc get priorityclass

# Check if higher priority pods are preventing scheduling
oc get pods --all-namespaces --sort-by=.spec.priority
```

## Monitoring and Metrics

### 1. Prometheus Metrics for Resource Monitoring
```bash
# Node CPU usage
node_cpu_seconds_total

# Node memory usage  
node_memory_MemAvailable_bytes

# Pod resource requests
kube_pod_container_resource_requests

# Scheduler metrics
scheduler_pending_pods
scheduler_scheduling_duration_seconds
```

### 2. OpenShift Console Metrics
- Navigate to Observe → Metrics
- Use queries like:
  ```
  # Node CPU utilization
  (1 - rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100
  
  # Pod CPU requests vs limits
  sum(kube_pod_container_resource_requests{resource="cpu"}) by (node)
  ```

### 3. CLI Resource Monitoring
```bash
# Real-time resource usage
oc adm top nodes
oc adm top pods --all-namespaces

# Resource allocation summary
oc describe node | grep -A 5 "Allocated resources"
```

## Best Practices for Resource Management

### 1. Right-sizing Resource Requests
```yaml
# Start conservative and adjust based on monitoring
resources:
  requests:
    cpu: 100m      # Start with 0.1 CPU
    memory: 128Mi  # Start with 128MB
  limits:
    cpu: 500m      # Allow bursting to 0.5 CPU
    memory: 512Mi  # Hard limit at 512MB
```

### 2. Horizontal Pod Autoscaler (HPA)
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ecr-credentials-sync-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ecr-credentials-sync
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### 3. Pod Disruption Budgets
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ecr-credentials-sync-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: ecr-credentials-sync
```

## Common Troubleshooting Scenarios

### Scenario 1: Pod Stuck in Pending
```bash
# Diagnosis steps:
1. oc describe pod <pod-name> -n <namespace>
2. Check Events section for FailedScheduling
3. oc get nodes -o wide
4. oc describe nodes | grep -A 5 "Allocated resources"
5. oc get machinesets -n openshift-machine-api
```

### Scenario 2: Cluster Not Scaling
```bash
# Check autoscaler status:
1. oc get clusterautoscaler
2. oc get machineautoscaler -n openshift-machine-api
3. oc logs -n openshift-machine-api -l k8s-app=cluster-autoscaler
4. oc get events -n openshift-machine-api
```

### Scenario 3: Nodes Not Ready
```bash
# Check node status:
1. oc get nodes
2. oc describe node <node-name>
3. oc get machines -n openshift-machine-api
4. oc describe machine <machine-name> -n openshift-machine-api
```

## Integration with Monitoring Stack

### Grafana Dashboards
- **Kubernetes / Compute Resources / Cluster**: Overall cluster resource utilization
- **Kubernetes / Compute Resources / Namespace (Pods)**: Pod-level resource usage
- **Node Exporter / Nodes**: Detailed node metrics

### Alerting Rules
```yaml
# Example alert for high node CPU usage
- alert: NodeCPUUsageHigh
  expr: (1 - rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100 > 80
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Node CPU usage is above 80%"
    
# Example alert for pending pods
- alert: PodsPending
  expr: kube_pod_status_phase{phase="Pending"} > 0
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Pods are stuck in Pending state"
```

## Conclusion

Understanding pod scheduling and resource contention requires analyzing multiple data points:

1. **Pod Events**: Primary indicator of scheduling failures
2. **Node Resources**: Understanding capacity and allocation
3. **Autoscaler Configuration**: Ensuring proper scaling limits
4. **Scheduler Logic**: Understanding how placement decisions are made
5. **Monitoring Metrics**: Proactive identification of resource issues

The key to effective troubleshooting is following the event trail from pod creation through scheduler decisions to cluster scaling responses.