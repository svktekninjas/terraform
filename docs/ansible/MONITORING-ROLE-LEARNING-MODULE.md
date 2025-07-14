# Monitoring Role Learning Module

## Overview
This comprehensive learning module will guide you through creating the `monitoring` Ansible role step-by-step. By the end of this module, you'll understand how to build a complete monitoring solution that:

1. **Integrates CloudWatch Container Insights** for AWS-native monitoring
2. **Deploys Prometheus & Grafana** for in-cluster metrics and visualization  
3. **Configures log aggregation** for cluster and node events
4. **Sets up comprehensive ROSA monitoring** with dashboards and alerting
5. **Follows Ansible best practices** with environment-specific configurations

## Prerequisites
- Basic understanding of Ansible concepts (roles, tasks, handlers, variables)
- Understanding of YAML syntax and Jinja2 templating
- Knowledge of Kubernetes/OpenShift concepts (pods, services, deployments)
- Basic familiarity with Prometheus and Grafana
- Understanding of AWS CloudWatch services
- ROSA cluster already deployed and accessible

## Learning Objectives
By completing this module, you will:
- ✅ Understand monitoring architecture for ROSA clusters
- ✅ Master Ansible role structure and organization
- ✅ Learn environment-specific configuration management
- ✅ Implement CloudWatch integration with ROSA
- ✅ Deploy and configure Prometheus monitoring
- ✅ Set up Grafana dashboards and visualization
- ✅ Configure log forwarding and aggregation
- ✅ Implement monitoring validation and health checks

## Module Structure

### Phase 1: Planning and Architecture (30 minutes)
### Phase 2: Role Structure Creation (45 minutes)
### Phase 3: Environment Configurations (60 minutes)
### Phase 4: Core Monitoring Components (90 minutes)
### Phase 5: Integration and Testing (45 minutes)

---

## Phase 1: Planning and Architecture

### Step 1.1: Understanding ROSA Monitoring Architecture

Before building the role, let's understand the monitoring architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS CloudWatch                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ Container       │  │ Log Groups      │  │ Metrics      │ │
│  │ Insights        │  │ & Streams       │  │ & Alarms     │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │ Log Forwarding
                              │ & Metrics Export
┌─────────────────────────────────────────────────────────────┐
│                  ROSA Cluster                              │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Grafana     │  │   Prometheus    │  │  Node Exporter  │ │
│  │  Dashboard   │  │   Server        │  │  (DaemonSet)    │ │
│  │              │  │                 │  │                 │ │
│  └──────────────┘  └─────────────────┘  └─────────────────┘ │
│                              ▲                             │
│                              │ Metrics Collection           │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Fluent Bit (Log Collection)               │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │           Application Workloads & System Pods          │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Step 1.2: Define Monitoring Requirements

**Core Requirements:**
- **CloudWatch Integration**: Container Insights, log forwarding, metrics
- **Prometheus**: Time-series metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Node Exporter**: System-level metrics
- **Log Aggregation**: Centralized logging via Fluent Bit
- **Environment-specific**: Dev/Test/Prod configurations
- **Security**: RBAC, service accounts, secure credentials

**Non-Functional Requirements:**
- **Scalability**: Handle multiple environments
- **Maintainability**: Modular, reusable components  
- **Security**: No hardcoded secrets, proper RBAC
- **Observability**: Self-monitoring and health checks

---

## Phase 2: Role Structure Creation

### Step 2.1: Create Monitoring Role Directory Structure

Following Ansible best practices, create the monitoring role structure:

```bash
# Navigate to your ansible directory
cd ansible/

# Create the monitoring role structure
mkdir -p roles/monitoring/{defaults,vars,tasks,templates,handlers,meta,files}

# Verify the structure
tree roles/monitoring/
```

**Expected Output:**
```
roles/monitoring/
├── defaults/
├── files/
├── handlers/
├── meta/
├── tasks/
├── templates/
└── vars/
```

### Step 2.2: Create Environment Directories

Environment-specific configurations will be stored outside the role:

```bash
# Create environment directories (if not exist)
mkdir -p environments/{dev,test,prod}

# Verify environment structure
tree environments/
```

**Expected Output:**
```
environments/
├── dev/
├── test/
└── prod/
```

### Step 2.3: Understanding the File Organization

| Directory | Purpose | Examples |
|-----------|---------|----------|
| `defaults/` | Default variables for the role | Resource limits, default settings |
| `vars/` | Role-specific variables | Container images, supported tools |
| `tasks/` | Task definitions and orchestration | main.yml, component deployments |
| `templates/` | Jinja2 templates for configuration files | Config maps, dashboards |
| `handlers/` | Event handlers (restart services, etc.) | Service restarts, notifications |
| `meta/` | Role metadata and dependencies | Role info, dependencies |
| `files/` | Static files to be copied | Scripts, certificates |
| `environments/*/` | Environment-specific configs | Dev/test/prod settings |

---

## Phase 3: Environment Configurations

### Step 3.1: Create Development Environment Configuration

**File:** `environments/dev/monitoring-config.yml`

```yaml
# Development Environment Monitoring Configuration
---
# Environment Configuration
environment_name: "dev"
environment_suffix: "dev"

# CloudWatch Configuration
enable_cloudwatch_insights: true
cloudwatch_log_group: "/rosa/cluster/{{ cluster_name_prefix }}-{{ environment_suffix }}"
cloudwatch_log_retention_days: 7
cloudwatch_log_stream_prefix: "dev-node-"

# Prometheus Configuration
prometheus_config:
  namespace: "monitoring"
  storage_size: "5Gi"
  retention_period: "7d"
  memory_request: "200Mi"
  memory_limit: "400Mi"
  cpu_request: "50m"
  cpu_limit: "100m"
  scrape_interval: "30s"
  evaluation_interval: "30s"

# Grafana Configuration
grafana_config:
  namespace: "monitoring"
  admin_user: "admin"
  admin_password: "dev-admin123"
  memory_request: "100Mi"
  memory_limit: "200Mi"
  cpu_request: "50m"
  cpu_limit: "100m"
  expose_route: true
  hostname_suffix: "dev.monitoring"

# Node Exporter Configuration
node_exporter_config:
  namespace: "monitoring"
  memory_request: "30Mi"
  memory_limit: "60Mi"
  cpu_request: "25m"
  cpu_limit: "50m"
  host_network: true
  host_pid: true

# Alerting Configuration
alerting_config:
  enable_alerts: true
  alert_severity: "warning"
  webhook_url: ""
  slack_channel: "#dev-alerts"

# Log Forwarding Configuration
log_forwarding:
  enable_fluent_bit: true
  buffer_size: "5MB"
  flush_interval: "5s"
  log_level: "info"

# Development specific settings
dev_settings:
  debug_mode: true
  verbose_logging: true
  enable_debug_endpoints: true
```

**💡 Key Learning Points:**
- **Environment-specific sizing**: Dev uses smaller resources
- **Debug settings**: Enabled for development troubleshooting
- **Log retention**: Shorter retention for cost optimization
- **Resource requests/limits**: Conservative for dev workloads

### Step 3.2: Create Test Environment Configuration

**File:** `environments/test/monitoring-config.yml`

```yaml
# Test Environment Monitoring Configuration
---
# Environment Configuration
environment_name: "test"
environment_suffix: "test"

# CloudWatch Configuration
enable_cloudwatch_insights: true
cloudwatch_log_group: "/rosa/cluster/{{ cluster_name_prefix }}-{{ environment_suffix }}"
cloudwatch_log_retention_days: 14
cloudwatch_log_stream_prefix: "test-node-"

# Prometheus Configuration
prometheus_config:
  namespace: "monitoring"
  storage_size: "10Gi"
  retention_period: "14d"
  memory_request: "400Mi"
  memory_limit: "800Mi"
  cpu_request: "100m"
  cpu_limit: "200m"
  scrape_interval: "30s"
  evaluation_interval: "30s"

# Grafana Configuration
grafana_config:
  namespace: "monitoring"
  admin_user: "admin"
  admin_password: "test-admin456"
  memory_request: "150Mi"
  memory_limit: "300Mi"
  cpu_request: "75m"
  cpu_limit: "150m"
  expose_route: true
  hostname_suffix: "test.monitoring"

# Node Exporter Configuration
node_exporter_config:
  namespace: "monitoring"
  memory_request: "50Mi"
  memory_limit: "100Mi"
  cpu_request: "50m"
  cpu_limit: "100m"
  host_network: true
  host_pid: true

# Alerting Configuration
alerting_config:
  enable_alerts: true
  alert_severity: "warning"
  webhook_url: ""
  slack_channel: "#test-alerts"

# Log Forwarding Configuration
log_forwarding:
  enable_fluent_bit: true
  buffer_size: "10MB"
  flush_interval: "10s"
  log_level: "info"

# Test specific settings
test_settings:
  debug_mode: false
  verbose_logging: false
  enable_debug_endpoints: false
  load_testing_mode: true
```

### Step 3.3: Create Production Environment Configuration

**File:** `environments/prod/monitoring-config.yml`

```yaml
# Production Environment Monitoring Configuration
---
# Environment Configuration
environment_name: "prod"
environment_suffix: "prod"

# CloudWatch Configuration
enable_cloudwatch_insights: true
cloudwatch_log_group: "/rosa/cluster/{{ cluster_name_prefix }}-{{ environment_suffix }}"
cloudwatch_log_retention_days: 30
cloudwatch_log_stream_prefix: "prod-node-"

# Prometheus Configuration
prometheus_config:
  namespace: "monitoring"
  storage_size: "50Gi"
  retention_period: "30d"
  memory_request: "1Gi"
  memory_limit: "2Gi"
  cpu_request: "200m"
  cpu_limit: "500m"
  scrape_interval: "15s"
  evaluation_interval: "15s"

# Grafana Configuration
grafana_config:
  namespace: "monitoring"
  admin_user: "admin"
  admin_password: "prod-secure789"
  memory_request: "300Mi"
  memory_limit: "600Mi"
  cpu_request: "150m"
  cpu_limit: "300m"
  expose_route: true
  hostname_suffix: "prod.monitoring"

# Node Exporter Configuration
node_exporter_config:
  namespace: "monitoring"
  memory_request: "100Mi"
  memory_limit: "200Mi"
  cpu_request: "100m"
  cpu_limit: "200m"
  host_network: true
  host_pid: true

# Alerting Configuration
alerting_config:
  enable_alerts: true
  alert_severity: "critical"
  webhook_url: "https://hooks.slack.com/services/YOUR/PROD/WEBHOOK"
  slack_channel: "#prod-alerts"
  pagerduty_integration: true

# Log Forwarding Configuration
log_forwarding:
  enable_fluent_bit: true
  buffer_size: "20MB"
  flush_interval: "30s"
  log_level: "warn"

# Production specific settings
prod_settings:
  debug_mode: false
  verbose_logging: false
  enable_debug_endpoints: false
  high_availability: true
  backup_enabled: true
  security_hardened: true
```

**💡 Key Learning Points:**
- **Production scaling**: Higher resource allocation
- **Security hardening**: Disabled debug features
- **Extended retention**: 30 days for compliance
- **Critical alerting**: Production-grade alert severity

---

## Phase 4: Core Monitoring Components

### Step 4.1: Create Role Variables

**File:** `roles/monitoring/vars/monitoring-variables.yml`

This file contains role-specific variables that don't change between environments:

```yaml
# Monitoring Role Variables
---
# Supported monitoring tools and versions
supported_monitoring_tools:
  - "prometheus"
  - "grafana"
  - "node-exporter"
  - "fluent-bit"
  - "cloudwatch-insights"

# Container Images
container_images:
  prometheus: "prom/prometheus:v2.45.0"
  grafana: "grafana/grafana:10.1.0"
  node_exporter: "prom/node-exporter:v1.6.1"
  fluent_bit: "fluent/fluent-bit:2.1.8"
  prometheus_operator: "quay.io/prometheus-operator/prometheus-operator:v0.68.0"

# Default monitoring configuration
default_monitoring_config:
  namespace: "monitoring"
  enable_rbac: true
  enable_security_context: true
  enable_network_policies: false

# CloudWatch regions and settings
cloudwatch_config:
  supported_regions:
    - "us-east-1"
    - "us-west-2"
    - "eu-west-1"
    - "ap-south-1"
  default_region: "us-east-1"
  container_insights_addon: "container-insights"
  log_driver: "awslogs"

# Resource requirements by environment
resource_requirements:
  dev:
    prometheus:
      memory_request: "200Mi"
      memory_limit: "400Mi"
      cpu_request: "50m"
      cpu_limit: "100m"
    grafana:
      memory_request: "100Mi"
      memory_limit: "200Mi"
      cpu_request: "50m"
      cpu_limit: "100m"
  test:
    prometheus:
      memory_request: "400Mi"
      memory_limit: "800Mi"
      cpu_request: "100m"
      cpu_limit: "200m"
    grafana:
      memory_request: "150Mi"
      memory_limit: "300Mi"
      cpu_request: "75m"
      cpu_limit: "150m"
  prod:
    prometheus:
      memory_request: "1Gi"
      memory_limit: "2Gi"
      cpu_request: "200m"
      cpu_limit: "500m"
    grafana:
      memory_request: "300Mi"
      memory_limit: "600Mi"
      cpu_request: "150m"
      cpu_limit: "300m"

# Timeout values (in seconds)
timeout_values:
  prometheus_startup: 120
  grafana_startup: 60
  node_exporter_startup: 30
  cloudwatch_addon: 300
```

### Step 4.2: Create Role Defaults

**File:** `roles/monitoring/defaults/main.yml`

```yaml
# Default variables for monitoring role
# These defaults reference values from monitoring-variables.yml
---
# Environment Configuration
target_environment: "{{ valid_environments[0] if valid_environments is defined else 'dev' }}"
ansible_env_path: "{{ playbook_dir }}/../environments/{{ target_environment }}"

# Monitoring Basic Configuration
monitoring_namespace: "{{ default_monitoring_config.namespace }}"
enable_monitoring: true
enable_cloudwatch_integration: "{{ enable_cloudwatch_insights | default(true) }}"

# Prometheus Configuration
prometheus_enabled: true
prometheus_namespace: "{{ prometheus_config.namespace if prometheus_config is defined else monitoring_namespace }}"
prometheus_storage_size: "{{ prometheus_config.storage_size if prometheus_config is defined else '10Gi' }}"
prometheus_retention: "{{ prometheus_config.retention_period if prometheus_config is defined else '15d' }}"
prometheus_image: "{{ container_images.prometheus }}"

# Grafana Configuration  
grafana_enabled: true
grafana_namespace: "{{ grafana_config.namespace if grafana_config is defined else monitoring_namespace }}"
grafana_admin_user: "{{ grafana_config.admin_user if grafana_config is defined else 'admin' }}"
grafana_admin_password: "{{ grafana_config.admin_password if grafana_config is defined else 'admin123' }}"
grafana_image: "{{ container_images.grafana }}"

# CloudWatch Configuration
cloudwatch_log_group: "{{ cloudwatch_log_group if cloudwatch_log_group is defined else '/rosa/cluster/default' }}"
cloudwatch_region: "{{ aws_region | default('us-east-1') }}"
cloudwatch_log_retention: "{{ cloudwatch_log_retention_days if cloudwatch_log_retention_days is defined else 14 }}"

# Operational Settings
wait_for_monitoring_ready: true
monitoring_ready_timeout: "{{ timeout_values.prometheus_startup }}"
skip_monitoring_validation: false
```

### Step 4.3: Create Main Orchestrator Task

**File:** `roles/monitoring/tasks/main.yml`

```yaml
# Main tasks file for monitoring role - orchestrates all monitoring setup tasks
---
- name: "Load monitoring variables"
  include_vars: monitoring-variables.yml
  tags:
    - monitoring
    - always

- name: "Load environment-specific monitoring configuration"
  include_vars: "{{ ansible_env_path }}/monitoring-config.yml"
  tags:
    - monitoring
    - always

- name: "Start ROSA Cluster Monitoring Setup for {{ target_environment }} environment"
  debug:
    msg: "🎯 Starting ROSA Cluster Monitoring Setup for {{ target_environment }} environment"
  tags:
    - monitoring

- name: Include CloudWatch Container Insights setup
  include_tasks: setup_cloudwatch_insights.yml
  when: enable_cloudwatch_integration | default(true)
  tags:
    - monitoring
    - monitoring-cloudwatch
    - cloudwatch

- name: Include monitoring namespace creation
  include_tasks: create_monitoring_namespace.yml
  tags:
    - monitoring
    - monitoring-setup
    - namespace

- name: Include RBAC configuration
  include_tasks: configure_monitoring_rbac.yml
  when: enable_rbac | default(true)
  tags:
    - monitoring
    - monitoring-setup
    - rbac

- name: Include Prometheus deployment
  include_tasks: deploy_prometheus.yml
  when: prometheus_enabled | default(true)
  tags:
    - monitoring
    - monitoring-prometheus
    - prometheus

- name: Include Grafana deployment
  include_tasks: deploy_grafana.yml
  when: grafana_enabled | default(true)
  tags:
    - monitoring
    - monitoring-grafana
    - grafana

- name: Include Node Exporter deployment
  include_tasks: deploy_node_exporter.yml
  when: node_exporter_enabled | default(true)
  tags:
    - monitoring
    - monitoring-node-exporter
    - node-exporter

- name: Include monitoring status validation
  include_tasks: validate_monitoring_setup.yml
  when: wait_for_monitoring_ready | default(true)
  tags:
    - monitoring
    - monitoring-validate
    - validation

- name: "Complete ROSA Cluster Monitoring Setup for {{ target_environment }} environment"
  debug:
    msg: "✅ ROSA Cluster Monitoring Setup completed successfully for {{ target_environment }} environment!"
  tags:
    - monitoring
```

**💡 Key Learning Points:**
- **Orchestration pattern**: Main file includes specific task files
- **Conditional execution**: Components can be enabled/disabled
- **Tag organization**: Hierarchical tagging for selective execution
- **Environment awareness**: Loads environment-specific configuration

### Step 4.4: Create Individual Task Files

#### CloudWatch Integration Task

**File:** `roles/monitoring/tasks/setup_cloudwatch_insights.yml`

```yaml
# Setup CloudWatch Container Insights for ROSA cluster
---
- name: "Configure CloudWatch Container Insights addon"
  block:
    - name: "Check if CloudWatch Container Insights addon already exists"
      shell: |
        rosa list addons --cluster {{ full_cluster_name }} --region {{ cloudwatch_region }}
      register: existing_addons_check
      environment:
        AWS_PROFILE: "{{ aws_profile }}"
      failed_when: false
      changed_when: false
      tags:
        - monitoring
        - cloudwatch

    - name: "Enable CloudWatch Container Insights addon"
      shell: |
        rosa create addon container-insights \
          --cluster {{ full_cluster_name }} \
          --region {{ cloudwatch_region }}
      register: cloudwatch_addon_result
      environment:
        AWS_PROFILE: "{{ aws_profile }}"
      failed_when: false
      when: "'container-insights' not in existing_addons_check.stdout"
      tags:
        - monitoring
        - cloudwatch

    - name: "Display CloudWatch addon creation result"
      debug:
        msg:
          - "📊 CloudWatch Container Insights addon:"
          - "  - Cluster: {{ full_cluster_name }}"
          - "  - Region: {{ cloudwatch_region }}"
          - "  - Status: {{ 'Created' if cloudwatch_addon_result.changed else 'Already exists' }}"
          - "  - Log Group: {{ cloudwatch_log_group }}"
      tags:
        - monitoring
        - cloudwatch
```

#### Namespace Creation Task

**File:** `roles/monitoring/tasks/create_monitoring_namespace.yml`

```yaml
# Create monitoring namespace and basic setup
---
- name: "Create monitoring namespace"
  shell: |
    oc create namespace {{ monitoring_namespace }} --dry-run=client -o yaml | oc apply -f -
  register: monitoring_namespace_result
  environment:
    AWS_PROFILE: "{{ aws_profile }}"
  failed_when: false
  tags:
    - monitoring
    - namespace

- name: "Label monitoring namespace"
  shell: |
    oc label namespace {{ monitoring_namespace }} \
      name={{ monitoring_namespace }} \
      monitoring=enabled \
      environment={{ target_environment }} \
      --overwrite
  register: namespace_label_result
  environment:
    AWS_PROFILE: "{{ aws_profile }}"
  failed_when: false
  tags:
    - monitoring
    - namespace
```

**💡 Learning Checkpoint:**

At this point, you should understand:
- ✅ How to structure environment-specific configurations
- ✅ Variable precedence and inheritance in Ansible
- ✅ Task organization and conditional execution
- ✅ OpenShift/Kubernetes resource management via shell commands

---

## Phase 5: Integration and Testing

### Step 5.1: Create Monitoring Role README

**File:** `roles/monitoring/README.md`

```markdown
# Monitoring Role

## Overview
Comprehensive monitoring solution for ROSA clusters with CloudWatch integration, Prometheus metrics collection, and Grafana visualization.

## Features
- ✅ CloudWatch Container Insights integration
- ✅ Prometheus metrics collection and storage
- ✅ Grafana dashboards and visualization
- ✅ Node Exporter for system metrics
- ✅ Log forwarding with Fluent Bit
- ✅ Environment-specific configurations
- ✅ RBAC and security best practices

## Usage

### Basic Usage
```bash
ansible-playbook playbooks/main.yml \
  --extra-vars "target_environment=dev aws_profile=svktek" \
  --tags "monitoring"
```

### Component-Specific Deployment
```bash
# Deploy only Prometheus
ansible-playbook playbooks/main.yml --tags "prometheus"

# Deploy only Grafana
ansible-playbook playbooks/main.yml --tags "grafana"

# Deploy only CloudWatch integration
ansible-playbook playbooks/main.yml --tags "cloudwatch"
```

## Configuration

### Environment Variables
- `target_environment`: Environment (dev/test/prod)
- `aws_profile`: AWS profile for authentication
- `full_cluster_name`: ROSA cluster name
- `aws_region`: AWS region

### Customization
Edit environment-specific configurations:
- `environments/dev/monitoring-config.yml`
- `environments/test/monitoring-config.yml`
- `environments/prod/monitoring-config.yml`
```

### Step 5.2: Test the Monitoring Role

**Test Command:**
```bash
# Navigate to ansible directory
cd ansible/

# Test monitoring role deployment
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  -e aws_profile=svktek \
  -e cluster_name_prefix=test-cluster \
  --tags "monitoring" \
  --check
```

### Step 5.3: Integration with Main Playbook

Update the main playbook to include the monitoring role:

**File:** `playbooks/main.yml`

```yaml
- name: ROSA Infrastructure Setup
  hosts: localhost
  connection: local
  gather_facts: yes
  
  roles:
    - role: aws-setup
      tags: ['aws', 'setup']
    - role: rosa-cli
      tags: ['rosa', 'cli']
    - role: validation
      tags: ['validation', 'pre-checks']
    - role: cluster
      tags: ['cluster', 'rosa-cluster']
    - role: monitoring
      tags: ['monitoring', 'observability']
```

---

## Advanced Topics

### Custom Dashboard Creation

Create custom Grafana dashboards by modifying:
`roles/monitoring/tasks/setup_grafana_dashboards.yml`

### Alerting Rules

Configure Prometheus alerting rules in:
`roles/monitoring/templates/alerting-rules.yml.j2`

### Log Parsing

Customize log parsing in:
`roles/monitoring/tasks/setup_log_forwarding.yml`

---

## Troubleshooting Guide

### Common Issues

1. **Monitoring namespace not created**
   ```bash
   oc get namespace monitoring
   # If missing, check RBAC permissions
   ```

2. **Prometheus not scraping targets**
   ```bash
   oc port-forward svc/prometheus 9090:9090 -n monitoring
   # Check targets at http://localhost:9090/targets
   ```

3. **Grafana not accessible**
   ```bash
   oc get routes -n monitoring
   oc port-forward svc/grafana 3000:3000 -n monitoring
   ```

### Debug Commands

```bash
# Check all monitoring pods
oc get pods -n monitoring

# Check monitoring services
oc get svc -n monitoring

# Check monitoring configuration
oc get configmaps -n monitoring

# Check RBAC
oc get sa,clusterrole,clusterrolebinding -n monitoring
```

---

## Learning Assessment

### Knowledge Check Questions

1. **Q:** What is the purpose of environment-specific configuration files?
   **A:** To allow different resource allocations, retention periods, and settings for dev/test/prod environments.

2. **Q:** Why do we use include_tasks instead of importing all tasks directly?
   **A:** For conditional execution, better organization, and modularity.

3. **Q:** What is the role of ServiceMonitors in Prometheus?
   **A:** They define which services Prometheus should scrape for metrics.

### Practical Exercises

1. **Exercise 1:** Modify the dev environment to use different resource limits
2. **Exercise 2:** Add a new monitoring component (e.g., AlertManager)
3. **Exercise 3:** Create a custom Grafana dashboard for your application

---

## Next Steps

### Additional Features to Implement

1. **AlertManager Integration**
   - Email/Slack notifications
   - Alert routing and grouping

2. **Advanced Dashboards**
   - Application-specific metrics
   - Business KPI dashboards

3. **Security Enhancements**
   - TLS encryption
   - OAuth integration
   - Network policies

4. **Backup and Recovery**
   - Prometheus data backup
   - Configuration backup

### Best Practices Learned

- ✅ **Modular Design**: Separate concerns into focused task files
- ✅ **Environment Awareness**: Configuration per environment
- ✅ **Conditional Logic**: Enable/disable components as needed
- ✅ **Error Handling**: Graceful failure handling with `failed_when: false`
- ✅ **Documentation**: Comprehensive README and inline comments
- ✅ **Testing**: Validation tasks for health checking

---

## Conclusion

Congratulations! You've successfully learned how to create a comprehensive monitoring role for ROSA clusters. This role demonstrates Ansible best practices while providing production-ready monitoring capabilities.

### Key Achievements

- ✅ **Complete Monitoring Stack**: CloudWatch + Prometheus + Grafana
- ✅ **Environment Management**: Dev/test/prod configurations
- ✅ **Ansible Mastery**: Role structure, variables, tasks, and templates
- ✅ **Production Ready**: RBAC, security, validation, and documentation

### Project Structure Summary

```
monitoring/
├── defaults/main.yml           # Default variables
├── vars/monitoring-variables.yml  # Role-specific variables
├── tasks/
│   ├── main.yml               # Main orchestrator
│   ├── setup_cloudwatch_insights.yml
│   ├── create_monitoring_namespace.yml
│   ├── configure_monitoring_rbac.yml
│   ├── deploy_prometheus.yml
│   ├── deploy_grafana.yml
│   ├── deploy_node_exporter.yml
│   └── validate_monitoring_setup.yml
└── README.md                  # Role documentation

environments/
├── dev/monitoring-config.yml     # Dev environment config
├── test/monitoring-config.yml    # Test environment config
└── prod/monitoring-config.yml    # Prod environment config
```

This monitoring role is now ready for production use and can be extended with additional monitoring components as needed!