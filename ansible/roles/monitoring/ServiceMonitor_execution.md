 ServiceMonitors Deployment and Troubleshooting Guide

  Overview

  This guide documents the complete process of deploying ServiceMonitors for Prometheus target discovery in a ROSA cluster, including all issues
  encountered, troubleshooting steps, and resolutions.

  Initial ServiceMonitors Deployment

  1. Task Execution

  Command Used:
  ansible-playbook -i environments/dev/inventory.yml playbooks/main.yml --extra-vars "target_environment=dev" --tags "servicemonitors" -v

  Purpose: Deploy ServiceMonitors to configure Prometheus target discovery for:
  - Node Exporter (custom deployment)
  - Prometheus (self-monitoring)
  - Kube-State-Metrics (Kubernetes object metrics)
  - Kubelet (container runtime metrics)
  - API Server (Kubernetes API metrics)

  2. Initial Deployment Results

  Validation Command:
  oc get servicemonitors -n monitoring

  Output:
  NAME                    AGE
  kube-state-metrics      4m28s
  kubelet                 4m27s
  kubernetes-apiservers   4m26s
  node-exporter           4m30s
  prometheus              4m29s

  Status: ✅ All 5 ServiceMonitors created successfully

  Issue Discovery and Analysis

  3. Detailed ServiceMonitor Inspection

  Commands Used:
  # Check Node Exporter ServiceMonitor
  oc describe servicemonitor node-exporter -n monitoring

  # Check Prometheus ServiceMonitor
  oc describe servicemonitor prometheus -n monitoring

  # Check problematic ServiceMonitors
  oc describe servicemonitor kubelet -n monitoring
  oc describe servicemonitor kubernetes-apiservers -n monitoring
  oc describe servicemonitor kube-state-metrics -n monitoring

  4. Issues Identified

  Issue #1: Kubelet ServiceMonitor Authentication Error

  Error Message:
  Warning  InvalidConfiguration  8m51s (x2 over 8m52s)  prometheus-controller
  ServiceMonitor kubelet was rejected due to invalid configuration:
  it accesses file system via bearer token file which Prometheus specification prohibits

  Root Cause:
  - ServiceMonitor configured with bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
  - OpenShift's Prometheus Operator prohibits direct file system access for security reasons

  Issue #2: API Server ServiceMonitor Authentication Error

  Error Message:
  Warning  InvalidConfiguration  8m52s  prometheus-controller
  ServiceMonitor kubernetes-apiservers was rejected due to invalid configuration:
  it accesses file system via bearer token file which Prometheus specification prohibits

  Root Cause: Same authentication issue as kubelet ServiceMonitor

  Issue #3: Kube-State-Metrics Target Not Found

  Analysis: ServiceMonitor created but no matching service exists
  Command to verify:
  oc get services -A -l app.kubernetes.io/name=kube-state-metrics
  Result: No services found

  5. Service Availability Check

  Commands Used:
  # Check monitoring namespace services
  oc get services -n monitoring

  # Check for kubelet service
  oc get services -n kube-system -l k8s-app=kubelet

  # Check for API server service
  oc get services -n default -l component=apiserver

  Results:
  # Monitoring namespace
  NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
  grafana               ClusterIP   172.30.75.151    <none>        3000/TCP   142m
  node-exporter         ClusterIP   172.30.80.40     <none>        9101/TCP   68m
  prometheus            ClusterIP   172.30.255.180   <none>        9090/TCP   176m
  prometheus-operated   ClusterIP   None             <none>        9090/TCP   176m

  # Kube-system kubelet service
  NAME      TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                        AGE
  kubelet   ClusterIP   None         <none>        10250/TCP,10255/TCP,4194/TCP   16h

  # Default kubernetes service
  NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
  kubernetes   ClusterIP   172.30.0.1   <none>        443/TCP   17h

  Analysis: Required services exist but authentication configuration is problematic

  Problem Analysis and Decision Making

  6. Value Assessment Discussion

  Question Raised: Do ServiceMonitors for kubelet, API server, and kube-state-metrics provide real value in ROSA?

  Analysis:
  - ROSA Platform Monitoring: Already provides comprehensive monitoring for Kubernetes infrastructure
  - Authentication Complexity: Requires workarounds for OpenShift security constraints
  - Resource Duplication: Storing same metrics in both platform and custom Prometheus
  - Limited Access: Some metrics may be restricted in managed ROSA environment

  Decision: Remove problematic ServiceMonitors and focus on application-specific monitoring

  Resolution Implementation

  7. ServiceMonitor Cleanup

  Command Used:
  oc delete servicemonitor kube-state-metrics kubelet kubernetes-apiservers -n monitoring

  Output:
  servicemonitor.monitoring.coreos.com "kube-state-metrics" deleted
  servicemonitor.monitoring.coreos.com "kubelet" deleted
  servicemonitor.monitoring.coreos.com "kubernetes-apiservers" deleted

  8. Final Validation

  Command Used:
  oc get servicemonitors -n monitoring

  Output:
  NAME            AGE
  node-exporter   20m
  prometheus      20m

  Working ServiceMonitors Verification

  9. Prometheus Target Health Check

  Command Used:
  # Port-forward to Prometheus
  oc port-forward svc/prometheus 9090:9090 -n monitoring &
  sleep 3

  # Check target health
  curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job == "node-exporter" or .labels.job == 
  "prometheus") | {job: .labels.job, health: .health, lastScrape: .lastScrape}'

  # Cleanup port-forward
  pkill -f "port-forward.*prometheus"

  Output:
  {
    "job": "node-exporter",
    "health": "up",
    "lastScrape": "2025-07-13T20:48:55.772011128Z"
  }
  {
    "job": "node-exporter",
    "health": "up",
    "lastScrape": "2025-07-13T20:48:33.661874914Z"
  }
  {
    "job": "node-exporter",
    "health": "up",
    "lastScrape": "2025-07-13T20:48:53.582628609Z"
  }
  {
    "job": "node-exporter",
    "health": "up",
    "lastScrape": "2025-07-13T20:48:28.831137522Z"
  }
  {
    "job": "prometheus",
    "health": "up",
    "lastScrape": "2025-07-13T20:48:37.753199348Z"
  }

  Analysis:
  - ✅ Node Exporter: 4 healthy targets (all worker nodes)
  - ✅ Prometheus: 1 healthy target (self-monitoring)
  - ✅ All targets successfully scraped within 30-second intervals

  Final Results Summary

  Working ServiceMonitors Configuration

  Node Exporter ServiceMonitor

  apiVersion: monitoring.coreos.com/v1
  kind: ServiceMonitor
  metadata:
    name: node-exporter
    namespace: monitoring
  spec:
    selector:
      matchLabels:
        app: node-exporter
    endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
      honorLabels: true
    namespaceSelector:
      matchNames:
      - monitoring

  Prometheus ServiceMonitor

  apiVersion: monitoring.coreos.com/v1
  kind: ServiceMonitor
  metadata:
    name: prometheus
    namespace: monitoring
  spec:
    selector:
      matchLabels:
        app: prometheus
    endpoints:
    - port: web
      interval: 30s
      path: /metrics
      honorLabels: true
    namespaceSelector:
      matchNames:
      - monitoring

  Key Learnings and Best Practices

  1. ROSA Platform Integration

  - Leverage ROSA's built-in monitoring for Kubernetes infrastructure
  - Focus custom monitoring on application-specific metrics
  - Avoid duplicating platform-provided monitoring capabilities

  2. Authentication in OpenShift

  - Bearer token file access is restricted by Prometheus Operator security policies
  - Use service account tokens through proper OpenShift mechanisms
  - Consider platform-provided authentication methods

  3. ServiceMonitor Design Principles

  - Target only services that provide unique value
  - Ensure target services exist before creating ServiceMonitors
  - Use appropriate scrape intervals based on metric importance

  4. Troubleshooting Commands Reference

  # List ServiceMonitors
  oc get servicemonitors -n <namespace>

  # Describe ServiceMonitor for detailed info
  oc describe servicemonitor <name> -n <namespace>

  # Check Prometheus targets
  oc port-forward svc/prometheus 9090:9090 -n monitoring
  curl http://localhost:9090/targets

  # Verify target services exist
  oc get services -n <namespace> -l <label-selector>

  # Check Prometheus logs for scraping issues
  oc logs -f deployment/prometheus -n monitoring

  Conclusion

  The ServiceMonitors deployment was successfully completed with a streamlined approach:
  - Deployed: Node Exporter and Prometheus ServiceMonitors for application-specific monitoring
  - Removed: Problematic ServiceMonitors that duplicated ROSA platform capabilities
  - Result: Clean, functional monitoring setup with all targets healthy and actively scraped
  - Benefits: Reduced complexity, eliminated authentication issues, and focused on value-added monitoring
