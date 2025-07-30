# Naming Server (Eureka) Service - Execution Guide
## Complete Ansible Playbook Instructions & Validation Steps

This guide provides step-by-step instructions for deploying Naming Server (Eureka Service Discovery) using Ansible playbooks, including comprehensive validation of deployments, pods, services, and routes.

---

## Prerequisites

- Ansible installed with kubernetes.core collection
- OpenShift CLI (oc) installed and configured
- Access to OpenShift cluster with proper permissions
- ECR credentials configured for image pulling
- No dependencies - Naming Server is the foundational service discovery component

---

## Part 1: Pre-Deployment Validation

### Step 1: Verify Environment Setup

```bash
# Check OpenShift connection
oc whoami
oc project

# Verify current namespace
oc get namespace cf-dev

# Check ECR secret exists
oc get secret ecr-secret -n cf-dev

# Ensure no existing naming server conflicts
oc get deployment -n cf-dev | grep naming
oc get svc -n cf-dev | grep naming
```

### Step 2: Verify Ansible Structure

```bash
# Navigate to ansible directory
cd /path/to/ansible

# Verify role structure
ls -la roles/cf-deployment/
ls -la helm-charts/cf-microservices/charts/naming-server/

# Check playbook exists
ls -la playbooks/main.yml
```

---

## Part 2: Naming Server (Eureka) Deployment

### Method 1: Deploy Naming Server Only

```bash
# Deploy only Naming Server service
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_naming_server_only=true" \
  -e "environment=dev" \
  -e "naming_server_env_vars=[
    {'name': 'SERVER_PORT', 'value': '8761'},
    {'name': 'SPRING_PROFILES_ACTIVE', 'value': 'openshift'},
    {'name': 'EUREKA_CLIENT_REGISTER_WITH_EUREKA', 'value': 'false'},
    {'name': 'EUREKA_CLIENT_FETCH_REGISTRY', 'value': 'false'},
    {'name': 'SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL', 'value': 'http://naming-server-new:8761'},
    {'name': 'SPRING_BOOT_ADMIN_CLIENT_URL', 'value': 'http://spring-boot-admin:8082'}
  ]"
```

### Method 2: Deploy with Advanced Eureka Configuration

```bash
# Deploy with comprehensive Eureka server configuration
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_naming_server_only=true" \
  -e "environment=dev" \
  -e "helm_release_name=naming-server" \
  -e "helm_chart_path=helm-charts/cf-microservices" \
  -e "naming_server_replicas=1" \
  -e "naming_server_cpu_limit=500m" \
  -e "naming_server_memory_limit=512Mi" \
  -e "naming_server_env_vars=[
    {'name': 'SERVER_PORT', 'value': '8761'},
    {'name': 'SPRING_PROFILES_ACTIVE', 'value': 'openshift'},
    {'name': 'EUREKA_CLIENT_REGISTER_WITH_EUREKA', 'value': 'false'},
    {'name': 'EUREKA_CLIENT_FETCH_REGISTRY', 'value': 'false'},
    {'name': 'EUREKA_SERVER_ENABLE_SELF_PRESERVATION', 'value': 'false'},
    {'name': 'EUREKA_SERVER_EVICTION_INTERVAL_TIMER_IN_MS', 'value': '5000'},
    {'name': 'EUREKA_INSTANCE_HOSTNAME', 'value': 'naming-server-new'},
    {'name': 'EUREKA_INSTANCE_PREFER_IP_ADDRESS', 'value': 'true'},
    {'name': 'SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL', 'value': 'http://naming-server-new:8761'},
    {'name': 'SPRING_BOOT_ADMIN_CLIENT_URL', 'value': 'http://spring-boot-admin:8082'},
    {'name': 'MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE', 'value': 'health,info,metrics,env,eureka'},
    {'name': 'MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS', 'value': 'always'},
    {'name': 'LOGGING_LEVEL_ROOT', 'value': 'INFO'},
    {'name': 'LOGGING_LEVEL_COM_NETFLIX_EUREKA', 'value': 'DEBUG'}
  ]"
```

### Method 3: Deploy with High Availability Configuration

```bash
# Deploy with HA configuration (not recommended for single Eureka server)
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_naming_server_only=true" \
  -e "environment=dev" \
  -e "naming_server_env_vars=[
    {'name': 'SERVER_PORT', 'value': '8761'},
    {'name': 'SPRING_PROFILES_ACTIVE', 'value': 'openshift'},
    {'name': 'EUREKA_CLIENT_REGISTER_WITH_EUREKA', 'value': 'false'},
    {'name': 'EUREKA_CLIENT_FETCH_REGISTRY', 'value': 'false'},
    {'name': 'EUREKA_SERVER_ENABLE_SELF_PRESERVATION', 'value': 'true'},
    {'name': 'EUREKA_SERVER_RENEWAL_PERCENT_THRESHOLD', 'value': '0.85'},
    {'name': 'EUREKA_SERVER_RENEWAL_THRESHOLD_UPDATE_INTERVAL_MS', 'value': '15000'},
    {'name': 'EUREKA_INSTANCE_LEASE_RENEWAL_INTERVAL_IN_SECONDS', 'value': '30'},
    {'name': 'EUREKA_INSTANCE_LEASE_EXPIRATION_DURATION_IN_SECONDS', 'value': '90'}
  ]"
```

---

## Part 3: Deployment Validation & Verification

### Step 1: Verify Helm Release

```bash
# Check Helm release status
helm list -n cf-dev

# Get Helm release details
helm status cf-microservices -n cf-dev

# View current Helm values
helm get values cf-microservices -n cf-dev

# Check Helm release history
helm history cf-microservices -n cf-dev
```

Expected Output:
```
NAME                NAMESPACE   REVISION    UPDATED                                 STATUS      CHART                       APP VERSION
cf-microservices    cf-dev      X           2024-01-XX XX:XX:XX.XXXXXXX +0000 UTC  deployed    cf-microservices-0.1.0      1.0.0
```

### Step 2: Validate Deployment

```bash
# Check deployment status
oc get deployment naming-server-new -n cf-dev

# View deployment details
oc describe deployment naming-server-new -n cf-dev

# Check replica status
oc get rs -l app=naming-server-new -n cf-dev

# Monitor deployment rollout
oc rollout status deployment/naming-server-new -n cf-dev
```

Expected Output:
```
NAME                 READY   UP-TO-DATE   AVAILABLE   AGE
naming-server-new    1/1     1            1           2m45s
```

### Step 3: Validate Pods

```bash
# Check pod status
oc get pods -l app=naming-server-new -n cf-dev

# View pod details
oc describe pod -l app=naming-server-new -n cf-dev

# Check pod logs for Eureka server startup
oc logs -l app=naming-server-new -n cf-dev --tail=100

# Monitor pod startup in real-time
oc get pods -l app=naming-server-new -n cf-dev -w
```

Expected Output:
```
NAME                                  READY   STATUS    RESTARTS   AGE
naming-server-new-xxxxxxxxxx-xxxxx    1/1     Running   0          2m30s
```

### Step 4: Validate Service

```bash
# Check service status
oc get svc naming-server-new -n cf-dev

# View service details
oc describe svc naming-server-new -n cf-dev

# Test service connectivity
oc get endpoints naming-server-new -n cf-dev

# Test port forwarding
oc port-forward svc/naming-server-new 8761:8761 -n cf-dev &
```

Expected Output:
```
NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
naming-server-new    ClusterIP   172.30.xxx.xxx   <none>        8761/TCP   3m15s
```

### Step 5: Validate Route

```bash
# Check route status
oc get route naming-server-new -n cf-dev

# View route details
oc describe route naming-server-new -n cf-dev

# Test route accessibility
curl -k https://$(oc get route naming-server-new -n cf-dev -o jsonpath='{.spec.host}')/actuator/health
```

Expected Output:
```
NAME                 HOST/PORT                                             PATH   SERVICES            PORT   TERMINATION   WILDCARD
naming-server-new    naming-server-new-cf-dev.apps.cluster.domain.com           naming-server-new   8761   edge          None
```

---

## Part 4: Eureka Server Functionality Tests

### Step 1: Eureka Server Health & Status

```bash
# Get Naming Server URL
EUREKA_URL="https://$(oc get route naming-server-new -n cf-dev -o jsonpath='{.spec.host}')"
echo "Eureka Server URL: $EUREKA_URL"

# Test Eureka server health
curl -k "$EUREKA_URL/actuator/health" | jq .

# Test Eureka server info
curl -k "$EUREKA_URL/actuator/info" | jq .

# Check Eureka server status page
curl -k "$EUREKA_URL/" -s -o /dev/null -w "%{http_code}"

# Check Eureka applications registry
curl -k "$EUREKA_URL/eureka/apps" | xmllint --format -
```

### Step 2: Eureka REST API Tests

```bash
# Get all registered applications
curl -k "$EUREKA_URL/eureka/apps" -H "Accept: application/json" | jq .

# Check Eureka server status
curl -k "$EUREKA_URL/eureka/status" | xmllint --format -

# Test Eureka server metrics
curl -k "$EUREKA_URL/actuator/metrics" | jq .

# Check specific Eureka metrics
curl -k "$EUREKA_URL/actuator/metrics/eureka.server.registry.size" | jq .
```

### Step 3: Environment Variables Verification

```bash
# Check Eureka-specific environment variables
oc exec -it deployment/naming-server-new -n cf-dev -- env | grep -E "(EUREKA|SERVER_PORT|SPRING_PROFILES)"

# Verify Eureka client settings are disabled
oc exec -it deployment/naming-server-new -n cf-dev -- env | grep -E "(REGISTER_WITH_EUREKA|FETCH_REGISTRY)"

# Check Spring Boot Admin integration variables
oc exec -it deployment/naming-server-new -n cf-dev -- env | grep -E "(ADMIN_CLIENT)"
```

---

## Part 5: Integration & Service Registration Tests

### Step 1: Test Service Registration (Mock)

```bash
# Register a test service with Eureka (for testing purposes)
curl -k -X POST "$EUREKA_URL/eureka/apps/TEST-SERVICE" \
  -H "Content-Type: application/json" \
  -d '{
    "instance": {
      "instanceId": "test-service-instance-1",
      "hostName": "test-service",
      "app": "TEST-SERVICE",
      "ipAddr": "127.0.0.1",
      "port": {"$": 8080, "@enabled": true},
      "vipAddress": "test-service",
      "dataCenterInfo": {
        "@class": "com.netflix.appinfo.InstanceInfo$DefaultDataCenterInfo",
        "name": "MyOwn"
      }
    }
  }'

# Verify the test service is registered
curl -k "$EUREKA_URL/eureka/apps/TEST-SERVICE" | xmllint --format -

# Deregister the test service
curl -k -X DELETE "$EUREKA_URL/eureka/apps/TEST-SERVICE/test-service-instance-1"
```

### Step 2: Spring Boot Admin Integration Check

```bash
# Check if Spring Boot Admin can reach Naming Server
ADMIN_URL="https://$(oc get route spring-boot-admin -n cf-dev -o jsonpath='{.spec.host}' 2>/dev/null || echo 'spring-boot-admin-not-deployed')"

if [ "$ADMIN_URL" != "https://spring-boot-admin-not-deployed" ]; then
    curl -k "$ADMIN_URL/instances" | jq '.[] | select(.registration.name=="naming-server-new")'
    echo "Spring Boot Admin integration: Available"
else
    echo "Spring Boot Admin integration: Not available (deploy Spring Boot Admin first)"
fi
```

---

## Part 6: Performance & Resource Monitoring

### Step 1: Resource Usage

```bash
# Check CPU and memory usage
oc top pods -l app=naming-server-new -n cf-dev

# View resource limits and requests
oc describe pod -l app=naming-server-new -n cf-dev | grep -A 10 "Limits\|Requests"

# Check resource utilization over time
oc adm top pod naming-server-new-* -n cf-dev --containers
```

### Step 2: Eureka Server Metrics

```bash
# Get JVM metrics
curl -k "$EUREKA_URL/actuator/metrics/jvm.memory.used" | jq .

# Get Eureka-specific metrics
curl -k "$EUREKA_URL/actuator/metrics/eureka.server.registry.size" | jq .
curl -k "$EUREKA_URL/actuator/metrics/eureka.server.get.requests" | jq .
curl -k "$EUREKA_URL/actuator/metrics/eureka.server.registration.requests" | jq .

# Monitor HTTP request metrics
curl -k "$EUREKA_URL/actuator/metrics/http.server.requests" | jq .
```

---

## Part 7: Troubleshooting & Common Issues

### Issue 1: Pod Not Starting

```bash
# Check pod events
oc get events -n cf-dev --field-selector involvedObject.name=naming-server-new

# Check pod logs for startup errors
oc logs deployment/naming-server-new -n cf-dev --previous

# Check resource constraints
oc describe pod -l app=naming-server-new -n cf-dev | grep -A 15 "Conditions"

# Verify image pull issues
oc describe pod -l app=naming-server-new -n cf-dev | grep -A 5 "Events"
```

### Issue 2: Eureka Server Not Accessible

```bash
# Test internal connectivity
oc run test-pod --image=curlimages/curl -it --rm -- sh
# Inside pod: curl http://naming-server-new.cf-dev.svc.cluster.local:8761/actuator/health

# Check service endpoints
oc get endpoints naming-server-new -n cf-dev -o yaml

# Verify port configuration
oc exec -it deployment/naming-server-new -n cf-dev -- netstat -tlnp | grep 8761
```

### Issue 3: Route Access Issues

```bash
# Check route configuration
oc get route naming-server-new -n cf-dev -o yaml

# Test DNS resolution
nslookup $(oc get route naming-server-new -n cf-dev -o jsonpath='{.spec.host}')

# Check TLS certificate
openssl s_client -connect $(oc get route naming-server-new -n cf-dev -o jsonpath='{.spec.host}'):443 -servername $(oc get route naming-server-new -n cf-dev -o jsonpath='{.spec.host}')
```

### Issue 4: Service Registration Problems

```bash
# Check Eureka server logs for registration errors
oc logs deployment/naming-server-new -n cf-dev | grep -i "registration\|error\|exception"

# Verify Eureka server configuration
oc exec -it deployment/naming-server-new -n cf-dev -- env | grep EUREKA

# Test Eureka REST API manually
curl -k "$EUREKA_URL/eureka/apps" -v
```

---

## Part 8: Advanced Operations & Maintenance

### Rolling Updates

```bash
# Update image tag
helm upgrade cf-microservices helm-charts/cf-microservices \
  -n cf-dev \
  --set naming-server.image.tag=new-version \
  --wait

# Monitor rolling update
oc rollout status deployment/naming-server-new -n cf-dev

# Rollback if needed
oc rollout undo deployment/naming-server-new -n cf-dev
```

### Configuration Updates

```bash
# Update Eureka server configuration
helm upgrade cf-microservices helm-charts/cf-microservices \
  -n cf-dev \
  --set-string naming-server.deployment.env[0].name=EUREKA_SERVER_ENABLE_SELF_PRESERVATION \
  --set-string naming-server.deployment.env[0].value=true \
  --wait

# Restart deployment to pick up changes
oc rollout restart deployment/naming-server-new -n cf-dev
```

### Backup Configuration

```bash
# Export current configuration
oc get deployment naming-server-new -n cf-dev -o yaml > naming-server-deployment-backup.yaml
oc get service naming-server-new -n cf-dev -o yaml > naming-server-service-backup.yaml
oc get route naming-server-new -n cf-dev -o yaml > naming-server-route-backup.yaml

# Backup Helm values
helm get values cf-microservices -n cf-dev > helm-values-backup.yaml
```

---

## Part 9: Monitoring & Observability

### Application Logs

```bash
# View application logs
oc logs deployment/naming-server-new -n cf-dev --tail=100 -f

# Search for specific patterns
oc logs deployment/naming-server-new -n cf-dev | grep -i "error\|exception\|warn\|eureka"

# Monitor Eureka server registration events
oc logs deployment/naming-server-new -n cf-dev | grep -i "registration\|renewal\|cancel"
```

### Health Monitoring

```bash
# Continuous health monitoring
watch -n 10 "curl -k -s $EUREKA_URL/actuator/health | jq '.status'"

# Monitor Eureka registry size
watch -n 30 "curl -k -s $EUREKA_URL/actuator/metrics/eureka.server.registry.size | jq '.measurements[0].value'"

# Check readiness and liveness probes
oc describe pod -l app=naming-server-new -n cf-dev | grep -A 5 "Liveness\|Readiness"
```

### Eureka Dashboard Monitoring

```bash
# Access Eureka dashboard
echo "Eureka Dashboard: $EUREKA_URL"
echo "Direct access: curl -k $EUREKA_URL/"

# Monitor applications registration status
curl -k "$EUREKA_URL/lastn" -s | grep -o "registered\|cancelled" | sort | uniq -c
```

---

## Part 10: Integration Testing with Other Services

### Prepare for Service Integration

```bash
# Verify Naming Server is ready for client registrations
curl -k "$EUREKA_URL/eureka/apps" -H "Accept: application/json" | jq '.applications'

# Check Eureka server is responsive
TIME=$(curl -k -w "%{time_total}" -s -o /dev/null "$EUREKA_URL/actuator/health")
echo "Health check response time: ${TIME}s"

# Verify DNS resolution from other pods
oc run dns-test --image=busybox -it --rm -- nslookup naming-server-new.cf-dev.svc.cluster.local
```

---

## Part 11: Cleanup Commands

### Remove Naming Server Only

```bash
# Scale down to zero
oc scale deployment naming-server-new --replicas=0 -n cf-dev

# Delete resources (WARNING: This will break service discovery for all microservices)
oc delete deployment naming-server-new -n cf-dev
oc delete service naming-server-new -n cf-dev
oc delete route naming-server-new -n cf-dev
```

### Complete Cleanup

```bash
# Remove entire Helm release
helm uninstall cf-microservices -n cf-dev

# Verify cleanup
oc get all -l app=naming-server-new -n cf-dev
```

---

## Success Criteria Checklist

- [ ] Ansible playbook executes without errors
- [ ] Helm release shows as `deployed` status
- [ ] Deployment shows `1/1` ready replicas
- [ ] Pod is in `Running` state with `1/1` ready containers
- [ ] Service has proper ClusterIP and endpoints
- [ ] Route is accessible and returns HTTP 200
- [ ] Health endpoint returns `{"status": "UP"}`
- [ ] Eureka server dashboard is accessible
- [ ] Eureka REST API responds correctly
- [ ] `/eureka/apps` endpoint returns empty applications list initially
- [ ] Environment variables are properly set
- [ ] Application logs show successful Eureka server startup
- [ ] Eureka server is NOT registered with itself (client settings disabled)
- [ ] Port 8761 is properly configured and accessible
- [ ] Spring Boot Admin integration configured (if deployed)

---

## Eureka Server Integration Test Script

```bash
#!/bin/bash
# Naming Server (Eureka) Integration Test Script

NAMESPACE="cf-dev"
EUREKA_URL="https://$(oc get route naming-server-new -n $NAMESPACE -o jsonpath='{.spec.host}')"

echo "=== Naming Server (Eureka) Integration Test ==="
echo "Eureka Server URL: $EUREKA_URL"

# Test 1: Health Check
echo -n "Testing health endpoint... "
HEALTH=$(curl -k -s "$EUREKA_URL/actuator/health" | jq -r '.status')
if [ "$HEALTH" == "UP" ]; then
    echo "✓ PASSED"
else
    echo "✗ FAILED"
fi

# Test 2: Eureka Dashboard
echo -n "Testing Eureka dashboard... "
DASHBOARD=$(curl -k -s -o /dev/null -w "%{http_code}" "$EUREKA_URL/")
if [ "$DASHBOARD" == "200" ]; then
    echo "✓ PASSED"
else
    echo "✗ FAILED"
fi

# Test 3: Eureka REST API
echo -n "Testing Eureka REST API... "
API_RESPONSE=$(curl -k -s -o /dev/null -w "%{http_code}" "$EUREKA_URL/eureka/apps")
if [ "$API_RESPONSE" == "200" ]; then
    echo "✓ PASSED"
else
    echo "✗ FAILED"
fi

# Test 4: Registry Status
echo -n "Testing registry status... "
REGISTRY_SIZE=$(curl -k -s "$EUREKA_URL/actuator/metrics/eureka.server.registry.size" | jq -r '.measurements[0].value // 0')
echo "✓ PASSED (Registry size: $REGISTRY_SIZE)"

# Test 5: Self Registration Check
echo -n "Verifying server is not self-registered... "
SELF_REG=$(curl -k -s "$EUREKA_URL/eureka/apps" -H "Accept: application/json" | jq -r '.applications.application // [] | map(select(.name == "NAMING-SERVER-NEW")) | length')
if [ "$SELF_REG" == "0" ]; then
    echo "✓ PASSED (Not self-registered, as expected)"
else
    echo "✗ FAILED (Should not be self-registered)"
fi

echo "=== Test Complete ==="
echo "Eureka Server is ready to accept service registrations"
```

---

## Contact & Support

For issues or questions:
- Check application logs: `oc logs deployment/naming-server-new -n cf-dev`
- Review deployment events: `oc get events -n cf-dev`
- Test Eureka REST API: `curl -k $EUREKA_URL/eureka/apps`
- Consult Netflix Eureka documentation
- Contact DevOps team for infrastructure issues

**Important Note**: Naming Server (Eureka) is the foundational service for microservices architecture. Ensure it's fully operational before deploying other microservices that depend on service discovery.