⏺ Execution Instructions for Monitoring Routes External Access Task

  Ansible Playbook Command Executed

  ansible-playbook playbooks/main.yml --tags "routes" -e target_environment=dev -e aws_profile=svktek -e grafana_enabled=true -e
  monitoring_namespace=monitoring -e full_cluster_name=rosa-dev -e cluster_name_prefix=rosa -e expose_grafana=true -e expose_prometheus=true -e
  cloudwatch_region=us-east-1 -e grafana_admin_user=admin -e grafana_admin_password=dev-admin123 -vv

  Task Execution Details

  What Was Executed

  - Task: expose_monitoring_services.yml from monitoring role
  - Tags Used: routes to target only route creation tasks
  - Target Environment: dev
  - AWS Profile: svktek

  Routes Created Successfully

  1. Grafana Route
    - Service: grafana in monitoring namespace
    - Hostname: grafana-rosa-dev-dev.us-east-1.elb.amazonaws.com
    - Port: 3000
    - Status: ✅ Created successfully
  2. Prometheus Route
    - Service: prometheus in monitoring namespace
    - Hostname: prometheus-rosa-dev-dev.us-east-1.elb.amazonaws.com
    - Port: 9090
    - Status: ✅ Created successfully

  Issues Encountered

  None - Task executed without any errors or issues.

  Validation Commands Used

  Route Status Verification

  oc get routes -n monitoring

  Output:
  NAME         HOST/PORT                                           PATH   SERVICES     PORT   TERMINATION   WILDCARD
  grafana      grafana-rosa-dev-dev.us-east-1.elb.amazonaws.com          grafana      3000                 None
  prometheus   prometheus-rosa-dev-dev.us-east-1.elb.amazonaws.com       prometheus   9090                 None

  Route URL Extraction

  # Grafana URL
  oc get route grafana -n monitoring -o jsonpath='{.spec.host}'

  # Prometheus URL  
  oc get route prometheus -n monitoring -o jsonpath='{.spec.host}'

  Access Information

  Grafana Access

  - URL: http://grafana-rosa-dev-dev.us-east-1.elb.amazonaws.com
  - Admin User: admin
  - Admin Password: dev-admin123

  Prometheus Access

  - URL: http://prometheus-rosa-dev-dev.us-east-1.elb.amazonaws.com
  - Access: Direct access to Prometheus UI

  Alternative Access Methods

  If routes are not immediately available:
  # Port forward Grafana
  oc port-forward svc/grafana 3000:3000 -n monitoring

  # Port forward Prometheus
  oc port-forward svc/prometheus 9090:9090 -n monitoring

  Task Completion Status

  ✅ COMPLETED - All monitoring services successfully exposed via OpenShift routes with external access configured.
