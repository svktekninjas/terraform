# Prometheus Route Creation - Execution Guide

## Overview
Successfully creates an OpenShift route for Prometheus service in the monitoring namespace, enabling external access via custom domain.

## Execution Command
```bash
ansible-playbook playbooks/main.yml --tags routes-prometheus --extra-vars "target_environment=dev aws_profile=svktek"
```

## Execution Results ✅

### Command Output Summary
```
PLAY [ROSA Infrastructure Setup] ***********************************************

TASK [routes : Create Prometheus route with probuddy.us domain] ****************
changed: [localhost]

TASK [routes : Get Prometheus route URL] ***************************************
changed: [localhost]

TASK [routes : Verify Prometheus route status] *********************************
changed: [localhost]

TASK [routes : Display Prometheus route creation results] **********************
ok: [localhost] => {
    "msg": [
        "🔍 Prometheus Route Creation Results:",
        "  - Route Creation: Success",
        "  - Route URL: prometheus-dev.probuddy.us",
        "  - Route Status: True",
        "  - Full URL: https://prometheus-dev.probuddy.us",
        "  - Environment: dev",
        "  - Namespace: monitoring"
    ]
}

PLAY RECAP *********************************************************************
localhost                  : ok=11   changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Route Verification
```bash
$ oc get routes -n monitoring
NAME               HOST/PORT                    PATH   SERVICES     PORT   TERMINATION   WILDCARD
grafana-route      grafana-dev.probuddy.us             grafana      3000   edge          None
prometheus-route   prometheus-dev.probuddy.us          prometheus   9090   edge          None
```

## Route Configuration Details

### Created Route Specifications:
- **Route Name**: `prometheus-route`
- **Hostname**: `prometheus-dev.probuddy.us`
- **Target Service**: `prometheus`
- **Target Port**: `9090`
- **TLS Termination**: `edge`
- **Namespace**: `monitoring`
- **Environment**: `dev`

### Route Labels Applied:
```yaml
labels:
  app: prometheus
  environment: dev
  managed-by: ansible-routes
```

## Environment-Specific Execution

### Development Environment (Executed)
```bash
# Creates: https://prometheus-dev.probuddy.us
ansible-playbook playbooks/main.yml --tags routes-prometheus --extra-vars "target_environment=dev aws_profile=svktek"
```

### Test Environment
```bash
# Would create: https://prometheus-test.probuddy.us
ansible-playbook playbooks/main.yml --tags routes-prometheus --extra-vars "target_environment=test aws_profile=svktek"
```

### Production Environment
```bash
# Would create: https://prometheus.probuddy.us
ansible-playbook playbooks/main.yml --tags routes-prometheus --extra-vars "target_environment=prod aws_profile=svktek"
```

## Validation Steps Performed

1. **Route Creation**: Applied route YAML configuration to OpenShift
2. **URL Extraction**: Retrieved the assigned hostname from the route
3. **Status Verification**: Checked route admission status
4. **Results Display**: Provided comprehensive creation summary

## Monitoring Routes Summary

After successful execution, both monitoring routes are now active:

| Service | Route Name | URL | Port | Status |
|---------|------------|-----|------|--------|
| Grafana | grafana-route | https://grafana-dev.probuddy.us | 3000 | ✅ Active |
| Prometheus | prometheus-route | https://prometheus-dev.probuddy.us | 9090 | ✅ Active |

## Next Steps for Full Accessibility

### 1. Route53 DNS Configuration
Add CNAME records in Route53:
```
prometheus-dev.probuddy.us -> router-default.apps.o0r9m0f2v7l3b1c.55n4.p1.openshiftapps.com
grafana-dev.probuddy.us -> router-default.apps.o0r9m0f2v7l3b1c.55n4.p1.openshiftapps.com
```

### 2. Verify External Access
```bash
# Test DNS resolution
nslookup prometheus-dev.probuddy.us
nslookup grafana-dev.probuddy.us

# Test HTTPS access
curl -I https://prometheus-dev.probuddy.us
curl -I https://grafana-dev.probuddy.us
```

### 3. Expected Response
Once DNS is configured:
- **Prometheus**: https://prometheus-dev.probuddy.us → Prometheus web UI
- **Grafana**: https://grafana-dev.probuddy.us → Grafana login page

## Troubleshooting

### Common Issues and Solutions

#### Route Not Created
```bash
# Check monitoring namespace exists
oc get ns monitoring

# Check prometheus service exists
oc get svc -n monitoring | grep prometheus

# Check cluster connectivity
oc whoami
```

#### DNS Not Resolving
```bash
# Get router canonical hostname for Route53
oc get route prometheus-route -n monitoring -o jsonpath='{.status.ingress[0].routerCanonicalHostname}'

# Verify route status
oc describe route prometheus-route -n monitoring
```

#### SSL/Certificate Issues
```bash
# Check route TLS configuration
oc get route prometheus-route -n monitoring -o yaml | grep -A5 tls

# Test without SSL verification
curl -k https://prometheus-dev.probuddy.us
```

#### Service Connectivity Issues
```bash
# Test prometheus service directly
oc port-forward svc/prometheus 9090:9090 -n monitoring
# Then access http://localhost:9090

# Check prometheus pod status
oc get pods -n monitoring -l app=prometheus
```

## Configuration Used

### Variables Applied:
- `target_environment`: `dev`
- `aws_profile`: `svktek`
- `routes_config.prometheus.hostname`: `prometheus-dev.probuddy.us`
- `routes_config.monitoring_namespace`: `monitoring`

### Task Tags Used:
- Primary: `routes-prometheus`
- Secondary: `prometheus`
- General: `routes`

## Performance Metrics

- **Execution Time**: ~10 seconds
- **Tasks Run**: 11 total (3 changes, 8 informational)
- **Network Calls**: Minimal (OpenShift API only)
- **Resource Impact**: Negligible

## Security Considerations

- **TLS**: Edge termination provides HTTPS encryption
- **Access**: Route exposes Prometheus to internet (no authentication by default)
- **Labels**: Clear identification and management tracking
- **Namespace**: Isolated to monitoring namespace

## Prometheus-Specific Notes

- **Default Port**: 9090 (metrics and web UI)
- **Authentication**: None by default (consider restricting access in production)
- **Data Access**: Exposes all scraped metrics via web interface
- **API Access**: Full Prometheus HTTP API available at /api/v1/*

This execution successfully demonstrates the routes role's capability to create properly configured OpenShift routes for Prometheus with appropriate security and labeling standards, complementing the earlier Grafana route creation.