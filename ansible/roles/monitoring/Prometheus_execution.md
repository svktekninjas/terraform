   Execute Prometheus deployment task

   ansible-playbook playbooks/main.yml -e target_environment=dev -e cluster_name_prefix=svktek-clstr -e aws_profile=svktek -e full_cluster_name=svktek-clstr-dev --tags "prometheus" 


A. Check all pods in monitoring namespace
   $oc get pods -n monitoring
NAME         READY   AGE
prometheus   0/1     15m

B. Check the prometheus status 
   $oc describe statefulset prometheus -n monitoring
Name:               prometheus
Namespace:          monitoring
CreationTimestamp:  Sun, 13 Jul 2025 12:40:24 -0500
Selector:           app=prometheus
Labels:             app=prometheus
                    environment=dev
Annotations:        <none>
Replicas:           1 desired | 0 total
Update Strategy:    RollingUpdate
  Partition:        0
Pods Status:        0 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:           app=prometheus
                    environment=dev
  Service Account:  prometheus
  Containers:
   prometheus:
    Image:      prom/prometheus:v2.45.0
    Port:       9090/TCP
    Host Port:  0/TCP
    Args:
      --config.file=/etc/prometheus/prometheus.yml
      --storage.tsdb.path=/prometheus/
      --storage.tsdb.retention.time=7d
      --web.console.libraries=/etc/prometheus/console_libraries
      --web.console.templates=/etc/prometheus/consoles
      --web.enable-lifecycle
      --web.enable-admin-api
    Limits:
      cpu:     100m
      memory:  400Mi
    Requests:
      cpu:        50m
      memory:     200Mi
    Liveness:     http-get http://:9090/-/healthy delay=30s timeout=30s period=10s #success=1 #failure=3
    Readiness:    http-get http://:9090/-/ready delay=30s timeout=30s period=10s #success=1 #failure=3
    Environment:  <none>
    Mounts:
      /etc/prometheus from prometheus-config (rw)
      /prometheus from prometheus-storage (rw)
  Volumes:
   prometheus-config:
    Type:          ConfigMap (a volume populated by a ConfigMap)
    Name:          prometheus-config
    Optional:      false
  Node-Selectors:  <none>
  Tolerations:     <none>
Volume Claims:
  Name:          prometheus-storage
  StorageClass:  
  Labels:        app=prometheus
  Annotations:   <none>
  Capacity:      5Gi
  Access Modes:  [ReadWriteOnce]
Events:
  Type     Reason            Age                 From                    Message
  ----     ------            ----                ----                    -------
  Normal   SuccessfulCreate  14m                 statefulset-controller  create Claim prometheus-storage-prometheus-0 Pod prometheus-0 in StatefulSet prometheus success
  Warning  FailedCreate      96s (x19 over 14m)  statefulset-controller  create Pod prometheus-0 in StatefulSet prometheus failed error: pods "prometheus-0" is forbidden: unable to validate against any security context constraint: [provider "anyuid": Forbidden: not usable by user or serviceaccount, provider restricted-v2: .spec.securityContext.fsGroup: Invalid value: []int64{65534}: 65534 is not an allowed group, provider restricted-v2: .containers[0].runAsUser: Invalid value: 65534: must be in the ranges: [1001050000, 1001059999], provider "restricted": Forbidden: not usable by user or serviceaccount, provider "nonroot-v2": Forbidden: not usable by user or serviceaccount, provider "nonroot": Forbidden: not usable by user or serviceaccount, provider "pcap-dedicated-admins": Forbidden: not usable by user or serviceaccount, provider "hostmount-anyuid": Forbidden: not usable by user or serviceaccount, provider "hostmount-anyuid-v2": Forbidden: not usable by user or serviceaccount, provider "machine-api-termination-handler": Forbidden: not usable by user or serviceaccount, provider "hostnetwork-v2": Forbidden: not usable by user or serviceaccount, provider "hostnetwork": Forbidden: not usable by user or serviceaccount, provider "hostaccess": Forbidden: not usable by user or serviceaccount, provider "insights-runtime-extractor-scc": Forbidden: not usable by user or serviceaccount, provider "splunkforwarder": Forbidden: not usable by user or serviceaccount, provider "node-exporter": Forbidden: not usable by user or serviceaccount, provider "privileged": Forbidden: not usable by user or serviceaccount]

C. Checck on the configmap
   $oc get configmaps -n monitoring | grep prometheus
prometheus-config          1      16m

D. Check monitoring services
   $oc get services -n monitoring
NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
prometheus            ClusterIP   172.30.255.180   <none>        9090/TCP   17m
prometheus-operated   ClusterIP   None             <none>        9090/TCP   17m

 ✅ Status Summary:
  - StatefulSet: Created but pod failing to start
  - ConfigMap: prometheus-config created successfully
  - Service: prometheus service created successfully
  - Storage: PVC created successfully
  - Pod: Failing due to SCC constraints

  The Prometheus container is trying to run as UID 65534 which is outside OpenShift's allowed range (1001050000-1001059999). We need to fix the
  security context in the deployment.


Troubleshooting 
I can see the issue! The StatefulSet has hardcoded security context values on lines 102-103. Let me fix this by removing the specific user/group IDs and letting OpenShift assign them automatically:
Updated roles/monitoring/tasks/deploy_prometheus.yml with 2 removals
        99              serviceAccountName: prometheus
       100              securityContext:
       101                runAsNonRoot: true
       102 -              runAsUser: 65534
       103 -              fsGroup: 65534
       102              containers:
       103              - name: prometheus
       104                image: {{ prometheus_image }}

⏺ Now let's delete the current failing StatefulSet and redeploy it with the fixed security context:


Delete the failing Prometheus StatefulSet   
    $oc delete statefulset prometheus -n monitoring

Redeploy Prometheus with fixed security context

   ansible-playbook playbooks/main.yml -e target_environment=dev -e cluster_name_prefix=svktek-clstr -e aws_profile=svktek -e full_cluster_name=svktek-clstr-dev --tags "prometheus"  
    

⏺ Great! Now let's check if the Prometheus pod is starting correctly:
  oc get pods -n monitoring
  ⎿  NAME           READY   STATUS    RESTARTS   AGE
     prometheus-0   1/1     Running   0          65s

Check Prometheus logs
  oc logs prometheus-0 -n monitoring --tail=10
  ⎿ ts=2025-07-13T18:09:19.474Z caller=head.go:792 level=info component=tsdb msg="WAL replay completed" checkpoint_replay_duration=65.381µs wal_r
    eplay_duration=461.724µs wbl_replay_duration=177ns total_replay_duration=616.304µs
    ts=2025-07-13T18:09:19.571Z caller=main.go:1040 level=info fs_type=EXT4_SUPER_MAGIC
    … +13 lines (ctrl+r to expand)


⏺ Excellent! ✅ Prometheus deployment fixed and operational!

  Fix Summary:
  - Issue: Security context constraint violation (UID 65534 not allowed)
  - Solution: Removed hardcoded runAsUser: 65534 and fsGroup: 65534, kept only runAsNonRoot: true
  - Result: OpenShift automatically assigned valid UID within allowed range

  Current Status:
  - Pod: prometheus-0 is Running (1/1 Ready)
  - Configuration: Loaded successfully from /etc/prometheus/prometheus.yml
  - TSDB: Started and ready
  - Web Server: Ready to receive requests
  - Service Discovery: Kubernetes integration active

  Prometheus is now ready to collect metrics.
