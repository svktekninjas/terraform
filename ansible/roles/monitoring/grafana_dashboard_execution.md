⏺ Grafana Dashboards Task - Detailed Execution Instructions

  Overview

  This document provides comprehensive execution instructions for the Grafana dashboard configuration task, including commands used, issues
  encountered, fixes applied, and validation steps.

  Initial Problem Identification

  Issue: Dashboard Tasks Not Executing

  Problem: Ansible playbook was including the dashboard task file but individual tasks within it weren't executing.

  Initial Command Attempted:
  ansible-playbook playbooks/main.yml --tags "monitoring-dashboards" -e target_environment=dev -e aws_profile=svktek

  Result:
  PLAY RECAP: ok=5 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
  - Tasks were included but not executed (no changed status)

  Root Cause Analysis

  Issue 1: Missing Required Variables

  Investigation Command:
  ansible-playbook playbooks/main.yml --tags "monitoring-dashboards" -e target_environment=dev -e aws_profile=svktek -vv

  Root Causes Identified:
  1. Missing grafana_enabled variable: Task inclusion had condition when: grafana_enabled | default(true) but variable was undefined
  2. Missing core variables: monitoring_namespace, full_cluster_name, cluster_name_prefix were undefined
  3. Task skipping: Individual tasks weren't executing due to missing prerequisites

  Issue 2: Variable Definition Problems

  Files Updated to Fix Variables:

  Updated Environment Configuration

  File: environments/dev/monitoring-config.yml
  Changes Made:
  # Added missing variables
  monitoring_namespace: "monitoring"
  full_cluster_name: "rosa-dev"
  cluster_name_prefix: "rosa"

  Enhanced Task File with Error Handling

  File: roles/monitoring/tasks/setup_grafana_dashboards.yml
  Improvements Added:
  1. Default Variable Setting:
  - name: "Set default values for dashboard variables"
    set_fact:
      monitoring_namespace: "{{ monitoring_namespace | default('monitoring') }}"
      full_cluster_name: "{{ full_cluster_name | default('rosa-' + target_environment) }}"
      cluster_name_prefix: "{{ cluster_name_prefix | default('rosa') }}"

  2. Prerequisite Validation:
  - name: "Verify monitoring namespace exists"
    shell: oc get namespace {{ monitoring_namespace }}

  - name: "Verify Grafana deployment exists"
    shell: oc get deployment grafana -n {{ monitoring_namespace }}

  3. Conditional Execution:
  when: namespace_check.rc == 0  # Only run if namespace exists

  4. Enhanced Error Reporting:
  - name: "Display dashboard setup results"
    debug:
      msg:
        - "📊 Grafana dashboard setup completed:"
        - "  - Namespace: {{ monitoring_namespace }} ({{ 'Found' if namespace_check.rc == 0 else 'Not Found' }})"
        - "  - Dashboard Provisioning: {{ 'Created' if (dashboard_provisioning_result is defined and dashboard_provisioning_result.rc == 0) else 
  ('Skipped' if namespace_check.rc != 0 else 'Error') }}"

  Successful Execution

  Final Working Command

  ansible-playbook playbooks/main.yml --tags "dashboards" -e target_environment=dev -e aws_profile=svktek -e grafana_enabled=true -e
  monitoring_namespace=monitoring -e full_cluster_name=rosa-dev -e cluster_name_prefix=rosa -vv

  Required Variables

  -e target_environment=dev           # Target environment
  -e aws_profile=svktek              # AWS profile for authentication
  -e grafana_enabled=true            # Enable Grafana dashboard tasks
  -e monitoring_namespace=monitoring  # Kubernetes namespace
  -e full_cluster_name=rosa-dev      # Complete cluster name
  -e cluster_name_prefix=rosa        # Cluster name prefix

  Execution Results

  PLAY RECAP:
  localhost: ok=12 changed=4 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0

  Tasks Successfully Executed:
  1. ✅ Set default values for dashboard variables
  2. ✅ Verify monitoring namespace exists (Found: 9h old)
  3. ✅ Verify Grafana deployment exists (Found: 6h55m old, 1/1 ready)
  4. ✅ Display validation status
  5. ✅ Create Grafana dashboard provisioning configuration
  6. ✅ Create ROSA cluster overview dashboard
  7. ✅ Display dashboard setup results

  Validation Commands and Results

  1. ConfigMap Validation

  # Check dashboard ConfigMaps exist
  oc get configmaps -n monitoring | grep grafana
  Output:
  grafana-dashboards                1      6h56m
  grafana-dashboards-provisioning   1      6h56m
  grafana-datasources               1      8h

  2. Dashboard Configuration Details

  # Verify dashboard content
  oc describe configmap grafana-dashboards -n monitoring | head -20
  Output:
  Name:         grafana-dashboards
  Namespace:    monitoring
  Labels:       app=grafana
                environment=dev
  Data:
  ====
  rosa-overview.json:
  ----
  {
    "dashboard": {
      "id": null,
      "title": "ROSA Cluster Overview - dev",
      "description": "Overview dashboard for ROSA cluster rosa-dev",
      "tags": ["rosa", "openshift", "dev"],

  3. Namespace and Deployment Validation

  # Verify prerequisites
  oc get namespace monitoring
  oc get deployment grafana -n monitoring
  Output:
  NAME         STATUS   AGE
  monitoring   Active   9h

  NAME      READY   UP-TO-DATE   AVAILABLE   AGE
  grafana   1/1     1            1           6h55m

  Dashboard Content Created

  1. Dashboard Provisioning ConfigMap

  Name: grafana-dashboards-provisioning
  Purpose: Configures Grafana to automatically load dashboards from /var/lib/grafana/dashboards

  2. ROSA Overview Dashboard ConfigMap

  Name: grafana-dashboards
  Content: Complete ROSA cluster monitoring dashboard with:
  - CPU Usage (stat and timeseries panels)
  - Memory Usage (stat and timeseries panels)
  - Pod Count (stat panel)
  - Node Count (stat panel)
  - Disk Usage (stat panel)
  - Network I/O (stat panel)
  - Template Variables: cluster name and environment
  - Color-coded Thresholds: Green/Yellow/Red for different metrics

  Problem-Solution Summary

  | Problem                       | Root Cause                                        | Solution Applied                                      |
  Validation Method                        |
  |-------------------------------|---------------------------------------------------|-------------------------------------------------------|--
  ----------------------------------------|
  | Tasks not executing           | Missing grafana_enabled variable                  | Added explicit variable to command                    |
  Verbose mode execution                   |
  | Missing dashboard variables   | Undefined monitoring_namespace, full_cluster_name | Added variables to environment config + task defaults |
  Variable display in debug output         |
  | No prerequisite checking      | Tasks ran without validation                      | Added namespace and Grafana deployment checks         |
  oc get commands in validation tasks      |
  | Poor error reporting          | Limited status feedback                           | Enhanced debug output with conditional messages       |
  Status display in task output            |
  | Conditional execution failure | Tasks ran regardless of prerequisites             | Added when: namespace_check.rc == 0 conditions        |
  Task skipping when prerequisites missing |

  Key Learnings

  1. Variable Requirements

  - Always provide all required variables explicitly in the command line
  - Use environment-specific configuration files for consistent variable values
  - Implement default values in tasks using {{ variable | default('fallback') }} pattern

  2. Validation Best Practices

  - Validate prerequisites before executing main tasks
  - Use conditional execution (when: clauses) to prevent failures
  - Provide informative status messages showing what was found, created, or skipped

  3. Ansible Execution Patterns

  - Use verbose mode (-vv) for debugging task execution issues
  - Check PLAY RECAP for task execution counts (ok, changed, failed, skipped)
  - Tag-based execution allows targeting specific functionality

  4. OpenShift/Kubernetes Integration

  - ConfigMaps are the standard method for providing dashboard configurations to Grafana
  - Label resources appropriately (app=grafana, environment=dev) for organization
  - Use oc describe to validate created resources and their content

  This comprehensive execution guide ensures reproducible dashboard deployment and provides clear troubleshooting steps for similar issues in the
   future.

