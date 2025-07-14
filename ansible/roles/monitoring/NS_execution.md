 📋 Monitoring Role Tasks List

  Here are all the individual tasks we can execute with their specific tags:

  Available Monitoring Tasks:

  1. cloudwatch - CloudWatch Container Insights setup
  2. namespace - Create monitoring namespace
  3. rbac - Configure RBAC and service accounts
  4. prometheus - Deploy Prometheus server
  5. grafana - Deploy Grafana dashboard
  6. node-exporter - Deploy Node Exporter DaemonSet
  7. servicemonitors - Configure ServiceMonitors for scraping
  8. log-forwarding - Setup Fluent Bit log forwarding
  9. dashboards - Setup Grafana dashboards
  10. routes - Expose monitoring services
  11. validation - Validate monitoring setup

  🚀 Let's Execute Task by Task

  Task 1: CloudWatch Container Insights

 ansible-playbook playbooks/main.yml -e target_environment=dev -e cluster_name_prefix=svktek-clstr -e aws_profile=svktek -e full_cluster_name=svktek-clstr-dev --tags "namespace"

Validation: 
A. login to cluster using admin username and password which were created during cluster creation 
         $oc login https://api.o0r9m0f2v7l3b1c.55n4.p1.openshiftapps.com:6443 --username cluster-admin --password bx3gC-mEFV8-ecr2v-agiSv
B. get the namespace details
         $oc get namespace monitoring
         NAME         STATUS   AGE
         monitoring   Active   3m58s
C. check the details of namespace
         $oc describe namespace monitoring
         Name:         monitoring
         Labels:       environment=dev
                       kubernetes.io/metadata.name=monitoring
                       monitoring=enabled
                       name=monitoring
                       pod-security.kubernetes.io/audit=restricted
                       pod-security.kubernetes.io/audit-version=latest
                       pod-security.kubernetes.io/warn=restricted
                       pod-security.kubernetes.io/warn-version=latest
         Annotations:  openshift.io/sa.scc.mcs: s0:c32,c29
                       openshift.io/sa.scc.supplemental-groups: 1001050000/10000
                       openshift.io/sa.scc.uid-range: 1001050000/10000
              security.openshift.io/MinimallySufficientPodSecurityStandard: restricted
         Status:       Active

         No resource quota.

         No LimitRange resource.


D. Check ConfigMaps created in monitoring namespace 
         $oc get configmaps -n monitoring
         NAME                       DATA   AGE
         kube-root-ca.crt           1      5m26s
         monitoring-config          8      5m24s
         openshift-service-ca.crt   1      5m26s

                     
E. Check the configmap applied to the namespace
       $oc describe configmap monitoring-config -n monitoring
          Name:         monitoring-config
          Namespace:    monitoring
          Labels:       app=monitoring
                        environment=dev
          Annotations:  <none>

          Data
          ====
          cluster_name: svktek-clstr-dev
          debug_mode:   True
          environment:  dev
          grafana_admin_user: admin
          log_group:  /rosa/cluster/svktek-clstr-dev
          prometheus_retention: 7d
          verbose_logging:   True
          aws_region:  us-east-1

          BinaryData
          ====

          Events:  <none>



⏺ ✅ Namespace validation successful!

  The monitoring namespace was created properly with:
  - Status: Active
  - Labels: Correct environment=dev, monitoring=enabled labels applied
  - ConfigMap: monitoring-config created with dev environment settings
  - Security: OpenShift security contexts and pod security standards applied

  All namespace creation components are working correctly.

 
