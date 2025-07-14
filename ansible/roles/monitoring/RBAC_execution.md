  Execute monitoring RBAC configuration task 

   ansible-playbook playbooks/main.yml -e target_environment=dev -e cluster_name_prefix=svktek-clstr -e aws_profile=svktek -e full_cluster_name=svktek-clstr-dev --tags "rbac"

Validation 

A. Check service accounts created in monitoring namespace 
    $oc get serviceaccounts -n monitoring 

NAME            SECRETS   AGE
builder         1         32m
default         1         32m
deployer        1         32m
grafana         1         7m3s
node-exporter   1         7m3s
prometheus      1         7m4s

B. Check ClusterRoles created for monitoring
    $oc get clusterroles | grep monitoring

cluster-monitoring-operator                                 2025-07-13T03:29:52Z
cluster-monitoring-operator-namespaced                                                  2025-07-13T03:29:51Z
cluster-monitoring-view                                                                 2025-07-13T03:46:42Z
clusterurlmonitors.monitoring.openshift.io-v1alpha1-admin                               2025-07-13T04:04:51Z
clusterurlmonitors.monitoring.openshift.io-v1alpha1-crdview                             2025-07-13T04:04:51Z
clusterurlmonitors.monitoring.openshift.io-v1alpha1-edit                                2025-07-13T04:04:51Z
clusterurlmonitors.monitoring.openshift.io-v1alpha1-view                                2025-07-13T04:04:51Z
dns-monitoring                                                                          2025-07-13T03:32:59Z
monitoring-edit                                                                         2025-07-13T03:46:43Z
monitoring-rules-edit                                                                   2025-07-13T03:46:43Z
monitoring-rules-view                                                                   2025-07-13T03:46:43Z
node-exporter-monitoring                                                                2025-07-13T17:26:45Z
olm.og.openshift-cluster-monitoring.admin-2SOrzhaSHllEqB6Becsc9Z2BniBuXZxdBrPmIq        2025-07-13T03:33:35Z
olm.og.openshift-cluster-monitoring.edit-brB9auo7mhdQtycRdrSZm5XlKKbUjCe698FPlD         2025-07-13T03:33:35Z
olm.og.openshift-cluster-monitoring.view-9QCGFNcofBHQ2DeWEf2qFa4NWqTOGskUedO4Tz         2025-07-13T03:33:35Z
olm.og.openshift-customer-monitoring.admin-4JcHJpuBvHUOdJeghSCkEX6iaSWxo4bGd6RTqe       2025-07-13T03:57:01Z
olm.og.openshift-customer-monitoring.edit-2V45qOH3WNJt7S3rB0ZjCn4bBw06omuAr6cTXd        2025-07-13T03:57:01Z
olm.og.openshift-customer-monitoring.view-8oRkrw9XXZjRG2DxZyx6CdCgb7QPAytJAwpaX4        2025-07-13T03:57:01Z
prometheus-monitoring                                                                   2025-07-13T17:26:44Z
registry-monitoring                                                                     2025-07-13T03:29:28Z
routemonitors.monitoring.openshift.io-v1alpha1-admin                                    2025-07-13T04:04:51Z
routemonitors.monitoring.openshift.io-v1alpha1-crdview                                  2025-07-13T04:04:51Z
routemonitors.monitoring.openshift.io-v1alpha1-edit                                     2025-07-13T04:04:51Z
routemonitors.monitoring.openshift.io-v1alpha1-view                                     2025-07-13T04:04:51Z
router-monitoring                                                                       2025-07-13T03:33:00Z
system:monitoring                                                                       2025-07-13T03:27:41Z

C. Check ClusterRoleBindings for monitoring 
    $oc get clusterrolebindings | grep monitoring

cluster-monitoring-operator                                                                        ClusterRole/cluster-monitoring-operator                                                 14h
configure-alertmanager-operator-prom                                                               ClusterRole/cluster-monitoring-view                                                     13h
dns-monitoring                                                                                     ClusterRole/dns-monitoring                                                              14h
node-exporter-monitoring                                                                           ClusterRole/node-exporter-monitoring                                                    9m9s
prometheus-monitoring                                                                              ClusterRole/prometheus-monitoring                                                       9m9s
registry-monitoring                                                                                ClusterRole/registry-monitoring                                                         14h
router-monitoring                                                                                  ClusterRole/router-monitoring                                                           14h
system:monitoring                                                                                  ClusterRole/system:monitoring                                                           14h
telemeter-client-view                                                                              ClusterRole/cluster-monitoring-view                                                     13h
thanos-ruler-monitoring                                                                            ClusterRole/cluster-monitoring-view                                                     13h


D. Check Roles created in monitoring namespace
    $oc get roles -n monitoring

NAME      CREATED AT
grafana   2025-07-13T17:26:47Z

E. Check RoleBindings in monitoring namespace
    $oc get rolebindings -n monitoring

NAME                                                              ROLE                                   AGE
admin-dedicated-admins                                            ClusterRole/admin                      36m
admin-system:serviceaccounts:dedicated-admin                      ClusterRole/admin                      36m
alert-routing-edit-dedicated-admins                               ClusterRole/alert-routing-edit         36m
dedicated-admins-project-dedicated-admins                         ClusterRole/dedicated-admins-project   36m
dedicated-admins-project-system:serviceaccounts:dedicated-admin   ClusterRole/dedicated-admins-project   36m
grafana                                                           Role/grafana                           10m
system:deployers                                                  ClusterRole/system:deployer            36m
system:image-builders                                             ClusterRole/system:image-builder       36m
system:image-pullers                                              ClusterRole/system:image-puller        36m

⏺ ✅ RBAC configuration validation successful!

  The RBAC setup is complete with:
  - Service Accounts: prometheus, grafana, node-exporter created
  - ClusterRoles: prometheus-monitoring, node-exporter-monitoring created
  - ClusterRoleBindings: Both created and properly bound
  - Role/RoleBinding: grafana role and binding created in monitoring namespace

  All RBAC components are properly configured.

         
