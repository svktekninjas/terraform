# Grafana Route Creation - Execution Guide

## Overview
Successfully creates an OpenShift route for Grafana service in the monitoring namespace, enabling external access via custom domain.

## Execution Command
```bash
ansible-playbook playbooks/main.yml --tags routes-grafana --extra-vars "target_environment=dev aws_profile=svktek"
```

## Execution Results ✅

### Command Output Summary
```
PLAY [ROSA Infrastructure Setup] ***********************************************

TASK [routes : Create Grafana route with probuddy.us domain] *******************
changed: [localhost]

TASK [routes : Get Grafana route URL] ******************************************
changed: [localhost]

TASK [routes : Verify Grafana route status] ************************************
changed: [localhost]

TASK [routes : Display Grafana route creation results] *************************
ok: [localhost] => {
    "msg": [
        "📊 Grafana Route Creation Results:",
        "  - Route Creation: Success",
        "  - Route URL: grafana-dev.probuddy.us",
        "  - Route Status: True",
        "  - Full URL: https://grafana-dev.probuddy.us",
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
NAME            HOST/PORT                 PATH   SERVICES   PORT   TERMINATION   WILDCARD
grafana-route   grafana-dev.probuddy.us          grafana    3000   edge          None
```

## Route Configuration Details

### Created Route Specifications:
- **Route Name**: `grafana-route`
- **Hostname**: `grafana-dev.probuddy.us`
- **Target Service**: `grafana`
- **Target Port**: `3000`
- **TLS Termination**: `edge`
- **Namespace**: `monitoring`
- **Environment**: `dev`

### Route Labels Applied:
```yaml
labels:
  app: grafana
  environment: dev
  managed-by: ansible-routes
```

## Environment-Specific Execution

### Development Environment (Executed)
```bash
# Creates: https://grafana-dev.probuddy.us
ansible-playbook playbooks/main.yml --tags routes-grafana --extra-vars "target_environment=dev aws_profile=svktek"
```

### Test Environment
```bash
# Would create: https://grafana-test.probuddy.us
ansible-playbook playbooks/main.yml --tags routes-grafana --extra-vars "target_environment=test aws_profile=svktek"
```

### Production Environment
```bash
# Would create: https://grafana.probuddy.us
ansible-playbook playbooks/main.yml --tags routes-grafana --extra-vars "target_environment=prod aws_profile=svktek"
```

## Validation Steps Performed

1. **Route Creation**: Applied route YAML configuration to OpenShift
2. **URL Extraction**: Retrieved the assigned hostname from the route
3. **Status Verification**: Checked route admission status
4. **Results Display**: Provided comprehensive creation summary

## Next Steps for Full Accessibility

### 1. Route53 DNS Configuration
Add CNAME record in Route53:
```
grafana-dev.probuddy.us -> router-default.apps.o0r9m0f2v7l3b1c.55n4.p1.openshiftapps.com
```

### 2. Verify External Access
```bash
# Test DNS resolution
nslookup grafana-dev.probuddy.us

# Test HTTPS access
curl -I https://grafana-dev.probuddy.us
```

### 3. Expected Response
Once DNS is configured, accessing https://grafana-dev.probuddy.us should:
- Redirect to Grafana login page
- Show valid SSL certificate (edge termination)
- Allow full Grafana functionality

## Troubleshooting

### Common Issues and Solutions

#### Route Not Created
```bash
# Check monitoring namespace exists
oc get ns monitoring

# Check grafana service exists
oc get svc -n monitoring | grep grafana

# Check cluster connectivity
oc whoami
```

#### DNS Not Resolving
```bash
# Get router canonical hostname for Route53
oc get route grafana-route -n monitoring -o jsonpath='{.status.ingress[0].routerCanonicalHostname}'

# Verify route status
oc describe route grafana-route -n monitoring
```

#### SSL/Certificate Issues
```bash
# Check route TLS configuration
oc get route grafana-route -n monitoring -o yaml | grep -A5 tls

# Test without SSL verification
curl -k https://grafana-dev.probuddy.us
```

## Configuration Used

### Variables Applied:
- `target_environment`: `dev`
- `aws_profile`: `svktek`
- `routes_config.grafana.hostname`: `grafana-dev.probuddy.us`
- `routes_config.monitoring_namespace`: `monitoring`

### Task Tags Used:
- Primary: `routes-grafana`
- Secondary: `grafana`
- General: `routes`

## Performance Metrics

- **Execution Time**: ~10 seconds
- **Tasks Run**: 11 total (3 changes, 8 informational)
- **Network Calls**: Minimal (OpenShift API only)
- **Resource Impact**: Negligible

## Security Considerations

- **TLS**: Edge termination provides HTTPS encryption
- **Access**: Route exposes Grafana to internet (requires authentication)
- **Labels**: Clear identification and management tracking
- **Namespace**: Isolated to monitoring namespace

This execution successfully demonstrates the routes role's capability to create properly configured OpenShift routes for monitoring services with appropriate security and labeling standards.