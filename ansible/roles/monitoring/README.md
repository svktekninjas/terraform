# Monitoring Role

## Overview
Comprehensive monitoring solution for ROSA clusters featuring CloudWatch integration, Prometheus metrics collection, Grafana visualization, and centralized log forwarding. This role provides production-ready monitoring with environment-specific configurations.

## Features
- ✅ **CloudWatch Container Insights** - AWS-native monitoring and log aggregation
- ✅ **Prometheus Metrics Collection** - Time-series metrics with persistent storage
- ✅ **Grafana Dashboards** - Rich visualization and alerting
- ✅ **Node Exporter** - System-level metrics from all cluster nodes
- ✅ **Fluent Bit Log Forwarding** - Centralized log collection to CloudWatch
- ✅ **Environment-Specific Configs** - Dev/test/prod optimized settings
- ✅ **RBAC Security** - Proper service accounts and permissions
- ✅ **Health Validation** - Automated monitoring setup verification

## Prerequisites
- ROSA cluster deployed and accessible via `oc` CLI
- AWS CLI configured with appropriate permissions
- CloudWatch Container Insights addon supported in target region
- Sufficient cluster resources for monitoring components

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS CloudWatch                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ Container       │  │ Log Groups      │  │ Metrics      │ │
│  │ Insights        │  │ & Streams       │  │ & Alarms     │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │ Log/Metrics Export
┌─────────────────────────────────────────────────────────────┐
│                  ROSA Cluster                              │
│  ┌──────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Grafana     │  │   Prometheus    │  │  Node Exporter  │ │
│  │  Dashboard   │◄─┤   Server        │◄─┤  (DaemonSet)    │ │
│  │              │  │                 │  │                 │ │
│  └──────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Fluent Bit (Log Collection)               │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Basic Deployment
```bash
ansible-playbook playbooks/main.yml \
  --extra-vars "target_environment=dev aws_profile=your-profile cluster_name_prefix=your-cluster" \
  --tags "monitoring"
```

### Component-Specific Deployment
```bash
# Deploy only CloudWatch integration
ansible-playbook playbooks/main.yml --tags "cloudwatch"

# Deploy only Prometheus
ansible-playbook playbooks/main.yml --tags "prometheus"

# Deploy only Grafana
ansible-playbook playbooks/main.yml --tags "grafana"

# Deploy only log forwarding
ansible-playbook playbooks/main.yml --tags "log-forwarding"
```

## Required Variables

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `target_environment` | Environment (dev/test/prod) | **Yes** | `dev` |
| `aws_profile` | AWS profile name | **Yes** | `svktek` |
| `cluster_name_prefix` | ROSA cluster name prefix | **Yes** | `my-cluster` |
| `aws_region` | AWS region | No | `us-east-1` |

## Environment Configurations

The role uses environment-specific configurations stored in `environments/{env}/monitoring-config.yml`:

### Development Environment
- **Resources**: Minimal (200Mi RAM, 50m CPU for Prometheus)
- **Retention**: 7 days for logs and metrics
- **Debug**: Enabled for troubleshooting
- **Storage**: 5Gi for Prometheus

### Test Environment  
- **Resources**: Medium (400Mi RAM, 100m CPU for Prometheus)
- **Retention**: 14 days for logs and metrics
- **Debug**: Disabled
- **Storage**: 10Gi for Prometheus

### Production Environment
- **Resources**: High (1Gi RAM, 200m CPU for Prometheus)
- **Retention**: 30 days for logs and metrics
- **Security**: Hardened, no debug endpoints
- **Storage**: 50Gi for Prometheus
- **Alerting**: Critical severity with PagerDuty integration

## Component Details

### CloudWatch Integration
- **Container Insights**: Automatically enabled for cluster-wide metrics
- **Log Groups**: Environment-specific log organization
- **Log Retention**: Configurable per environment (7-30 days)
- **Regional Support**: Multi-region deployment capability

### Prometheus Configuration
- **Storage**: Persistent volume with environment-specific sizing
- **Retention**: Configurable time-series data retention
- **Scraping**: Automatic discovery of Kubernetes services
- **Security**: RBAC-enabled with service account authentication

### Grafana Setup
- **Dashboards**: Pre-configured ROSA cluster overview dashboard
- **Datasources**: Automatic Prometheus integration
- **Authentication**: Admin credentials via Kubernetes secrets
- **Access**: OpenShift routes or port-forwarding

### Node Exporter
- **Deployment**: DaemonSet on all worker nodes
- **Metrics**: System-level CPU, memory, disk, and network metrics
- **Security**: Non-root user with minimal privileges
- **Collection**: Host network and PID namespace access

### Log Forwarding
- **Fluent Bit**: Lightweight log processor on every node
- **Parsing**: Container and system log parsing
- **Destination**: CloudWatch Logs with structured metadata
- **Filtering**: Environment-specific log levels and routing

## Access Methods

### Grafana Dashboard
```bash
# Via OpenShift route (if exposed)
oc get routes -n monitoring

# Via port forwarding
oc port-forward svc/grafana 3000:3000 -n monitoring
# Access: http://localhost:3000
# Credentials: admin / {environment-specific-password}
```

### Prometheus Console
```bash
# Via port forwarding
oc port-forward svc/prometheus 9090:9090 -n monitoring
# Access: http://localhost:9090
```

### CloudWatch Console
```bash
# Log Groups
aws logs describe-log-groups --log-group-name-prefix "/rosa/cluster"

# Container Insights
# Navigate to CloudWatch Console > Container Insights > Performance monitoring
```

## Monitoring Capabilities

### Cluster Metrics
- **CPU Usage**: Cluster-wide and per-node CPU utilization
- **Memory Usage**: Available and used memory across nodes
- **Pod Count**: Total pods and pod distribution
- **Network I/O**: Ingress and egress traffic metrics
- **Disk Usage**: Filesystem usage and availability

### System Metrics
- **Node Health**: Individual node resource consumption
- **Container Metrics**: Per-container resource usage
- **Kubernetes Metrics**: API server, kubelet, and scheduler metrics
- **Custom Metrics**: Application-specific metrics via ServiceMonitors

### Log Collection
- **Container Logs**: All pod and container logs
- **System Logs**: Kubelet, CRI-O, and system service logs
- **Audit Logs**: Kubernetes API audit trail
- **Structured Metadata**: Environment, cluster, and namespace labels

## Troubleshooting

### Common Issues

#### Monitoring pods not starting
```bash
# Check namespace and pod status
oc get pods -n monitoring
oc describe pod <pod-name> -n monitoring

# Check resource constraints
oc get events -n monitoring --sort-by='.lastTimestamp'
```

#### Prometheus not scraping targets
```bash
# Access Prometheus UI and check targets
oc port-forward svc/prometheus 9090:9090 -n monitoring
# Visit: http://localhost:9090/targets

# Check ServiceMonitor configurations
oc get servicemonitors -n monitoring
```

#### Grafana login issues
```bash
# Check Grafana admin credentials
oc get secret grafana-admin -n monitoring -o yaml

# Reset Grafana pod
oc delete pod -l app=grafana -n monitoring
```

#### CloudWatch addon not working
```bash
# Check addon status
rosa list addons --cluster your-cluster-name

# Verify AWS permissions
aws logs describe-log-groups --log-group-name-prefix "/rosa/cluster"
```

### Debug Commands

```bash
# Monitor role deployment
ansible-playbook playbooks/main.yml --tags "monitoring" -v

# Check all monitoring resources
oc get all -n monitoring

# View monitoring configuration
oc get configmaps -n monitoring -o yaml

# Check RBAC permissions
oc get sa,clusterrole,clusterrolebinding -n monitoring

# Validate log forwarding
oc logs -l app=fluent-bit -n monitoring
```

## Customization

### Adding Custom Dashboards
1. Edit `roles/monitoring/tasks/setup_grafana_dashboards.yml`
2. Add dashboard JSON in ConfigMap format
3. Redeploy with `--tags "dashboards"`

### Modifying Resource Limits
1. Update environment-specific config: `environments/{env}/monitoring-config.yml`
2. Adjust `prometheus_config`, `grafana_config`, or `node_exporter_config`
3. Redeploy affected components

### Custom Alerting Rules
1. Create new task file: `roles/monitoring/tasks/setup_alerting_rules.yml`
2. Add to main.yml orchestrator
3. Deploy with monitoring tags

## Security Considerations

### RBAC Implementation
- **Service Accounts**: Dedicated accounts for each component
- **ClusterRoles**: Minimal required permissions
- **ClusterRoleBindings**: Secure permission assignments
- **Namespace Isolation**: Components isolated in monitoring namespace

### Credential Management
- **Kubernetes Secrets**: Admin passwords stored securely
- **AWS Credentials**: Profile-based authentication
- **TLS**: HTTPS endpoints where applicable
- **Non-root**: All containers run as non-root users

### Network Security
- **Service Mesh**: Compatible with Istio/OpenShift Service Mesh
- **Network Policies**: Optional cluster-level network isolation
- **Firewall Rules**: CloudWatch integration uses AWS endpoints

## Performance Tuning

### Resource Optimization
- **Environment Sizing**: Appropriate resource allocation per environment
- **Storage Management**: Configurable retention and storage size
- **Scrape Intervals**: Balanced between granularity and performance
- **Log Buffer**: Optimized log forwarding buffer sizes

### Scalability
- **Horizontal Scaling**: Grafana supports multiple replicas
- **Storage Scaling**: Prometheus storage can be expanded
- **Node Distribution**: DaemonSets automatically scale with nodes
- **Regional Distribution**: Multi-region deployment support

## Backup and Recovery

### Prometheus Data
```bash
# Manual backup (if needed)
oc exec -n monitoring prometheus-0 -- tar czf /tmp/prometheus-backup.tar.gz /prometheus

# Storage backup via PVC snapshots
oc get pvc -n monitoring
```

### Configuration Backup
```bash
# Export all monitoring configurations
oc get configmaps,secrets -n monitoring -o yaml > monitoring-backup.yaml
```

## Integration Examples

### Main Playbook Integration
```yaml
roles:
  - role: aws-setup
    tags: ['aws', 'setup']
  - role: cluster
    tags: ['cluster', 'rosa-cluster']
  - role: monitoring
    tags: ['monitoring', 'observability']
```

### Selective Component Deployment
```bash
# Deploy infrastructure first
ansible-playbook playbooks/main.yml --tags "aws,cluster"

# Add monitoring later
ansible-playbook playbooks/main.yml --tags "monitoring"
```

## Version Information
- **Role Version**: 1.0.0
- **Prometheus**: v2.45.0
- **Grafana**: v10.1.0
- **Node Exporter**: v1.6.1
- **Fluent Bit**: v2.1.8
- **Supported OpenShift**: 4.12+
- **Supported ROSA**: All versions

## License
MIT

## Support
For issues and support:
1. Check the troubleshooting section
2. Review logs with debug commands
3. Consult the learning module documentation
4. Contact the DevOps team

## Contributors
- DevOps Team - Consulting Firm
- Monitoring Architecture Design Team
- ROSA Infrastructure Team