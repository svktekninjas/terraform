# API Gateway Service - Execution Guide
## Complete Ansible Playbook Instructions & Validation Steps

This guide provides step-by-step instructions for deploying API Gateway service using Ansible playbooks, including comprehensive validation of deployments, pods, services, and routes.

---

## Prerequisites

- Ansible installed with kubernetes.core collection
- OpenShift CLI (oc) installed and configured
- Access to OpenShift cluster with proper permissions
- ECR credentials configured for image pulling
- Naming Server (Eureka) must be deployed first
- Spring Boot Admin should be deployed for monitoring

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

# Verify dependencies are running
oc get deployment naming-server-new -n cf-dev
oc get deployment spring-boot-admin -n cf-dev
```

### Step 2: Verify Ansible Structure

```bash
# Navigate to ansible directory
cd /path/to/ansible

# Verify role structure
ls -la roles/cf-deployment/
ls -la helm-charts/cf-microservices/charts/api-gateway/

# Check playbook exists
ls -la playbooks/main.yml
```

---

## Part 2: API Gateway Deployment

### Method 1: Deploy API Gateway Only

```bash
# Deploy only API Gateway service
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_api_gateway_only=true" \
  -e "environment=dev" \
  -e "api_gateway_env_vars=[
    {'name': 'SERVER_PORT', 'value': '8765'},
    {'name': 'SPRING_PROFILES_ACTIVE', 'value': 'openshift'},
    {'name': 'EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE', 'value': 'http://naming-server-new:8761/eureka'},
    {'name': 'SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL', 'value': 'http://apigateway-app:8765'},
    {'name': 'SPRING_BOOT_ADMIN_CLIENT_URL', 'value': 'http://spring-boot-admin:8082'}
  ]"
```

### Method 2: Deploy with Advanced Configuration

```bash
# Deploy with comprehensive configuration
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_api_gateway_only=true" \
  -e "environment=dev" \
  -e "helm_release_name=api-gateway" \
  -e "helm_chart_path=helm-charts/cf-microservices" \
  -e "api_gateway_replicas=2" \
  -e "api_gateway_cpu_limit=1000m" \
  -e "api_gateway_memory_limit=1Gi" \
  -e "api_gateway_env_vars=[
    {'name': 'SERVER_PORT', 'value': '8765'},
    {'name': 'SPRING_PROFILES_ACTIVE', 'value': 'openshift'},
    {'name': 'EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE', 'value': 'http://naming-server-new:8761/eureka'},
    {'name': 'EUREKA_INSTANCE_PREFER_IP_ADDRESS', 'value': 'true'},
    {'name': 'EUREKA_INSTANCE_HOSTNAME', 'value': 'apigateway-app'},
    {'name': 'SPRING_BOOT_ADMIN_CLIENT_INSTANCE_SERVICE_BASE_URL', 'value': 'http://apigateway-app:8765'},
    {'name': 'SPRING_BOOT_ADMIN_CLIENT_URL', 'value': 'http://spring-boot-admin:8082'},
    {'name': 'MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE', 'value': 'health,info,metrics,gateway'},
    {'name': 'MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS', 'value': 'always'},
    {'name': 'LOGGING_LEVEL_ROOT', 'value': 'INFO'},
    {'name': 'SPRING_CLOUD_GATEWAY_DISCOVERY_LOCATOR_ENABLED', 'value': 'true'}
  ]"
```

### Method 3: Deploy with Custom Routes Configuration

```bash
# Deploy with specific route configurations
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_api_gateway_only=true" \
  -e "environment=dev" \
  -e "api_gateway_env_vars=[
    {'name': 'SERVER_PORT', 'value': '8765'},
    {'name': 'SPRING_PROFILES_ACTIVE', 'value': 'openshift'},
    {'name': 'EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE', 'value': 'http://naming-server-new:8761/eureka'},
    {'name': 'SPRING_CLOUD_GATEWAY_ROUTES_0_ID', 'value': 'excel-service'},
    {'name': 'SPRING_CLOUD_GATEWAY_ROUTES_0_URI', 'value': 'lb://excel-service'},
    {'name': 'SPRING_CLOUD_GATEWAY_ROUTES_0_PREDICATES_0', 'value': 'Path=/excel/**'},
    {'name': 'SPRING_CLOUD_GATEWAY_ROUTES_1_ID', 'value': 'interviews-service'},
    {'name': 'SPRING_CLOUD_GATEWAY_ROUTES_1_URI', 'value': 'lb://interviews-service'},
    {'name': 'SPRING_CLOUD_GATEWAY_ROUTES_1_PREDICATES_0', 'value': 'Path=/interviews/**'}
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

# View Helm values
helm get values cf-microservices -n cf-dev
```

Expected Output:
```
NAME                NAMESPACE   REVISION    UPDATED                                 STATUS      CHART                       APP VERSION
cf-microservices    cf-dev      X           2024-01-XX XX:XX:XX.XXXXXXX +0000 UTC  deployed    cf-microservices-0.1.0      1.0.0
```

### Step 2: Validate Deployment

```bash
# Check deployment status
oc get deployment apigateway-app -n cf-dev

# View deployment details
oc describe deployment apigateway-app -n cf-dev

# Check replica status
oc get rs -l app=apigateway-app -n cf-dev

# Monitor deployment rollout
oc rollout status deployment/apigateway-app -n cf-dev
```

Expected Output:
```
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
apigateway-app   2/2     2            2           3m45s
```

### Step 3: Validate Pods

```bash
# Check pod status
oc get pods -l app=apigateway-app -n cf-dev

# View pod details
oc describe pod -l app=apigateway-app -n cf-dev

# Check pod logs
oc logs -l app=apigateway-app -n cf-dev --tail=100

# Monitor pod startup in real-time
oc get pods -l app=apigateway-app -n cf-dev -w
```

Expected Output:
```
NAME                              READY   STATUS    RESTARTS   AGE
apigateway-app-xxxxxxxxxx-xxxxx   1/1     Running   0          3m30s
apigateway-app-xxxxxxxxxx-yyyyy   1/1     Running   0          3m30s
```

### Step 4: Validate Service

```bash
# Check service status
oc get svc apigateway-app -n cf-dev

# View service details
oc describe svc apigateway-app -n cf-dev

# Test service connectivity
oc get endpoints apigateway-app -n cf-dev

# Test port forwarding
oc port-forward svc/apigateway-app 8765:8765 -n cf-dev &
```

Expected Output:
```
NAME             TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
apigateway-app   ClusterIP   172.30.xxx.xxx   <none>        8765/TCP   4m15s
```

### Step 5: Validate Route

```bash
# Check route status
oc get route apigateway-app -n cf-dev

# View route details
oc describe route apigateway-app -n cf-dev

# Test route accessibility
curl -k https://$(oc get route apigateway-app -n cf-dev -o jsonpath='{.spec.host}')/actuator/health
```

Expected Output:
```
NAME             HOST/PORT                                          PATH   SERVICES         PORT   TERMINATION   WILDCARD
apigateway-app   apigateway-app-cf-dev.apps.cluster.domain.com           apigateway-app   8765   edge          None
```

---

## Part 4: Service Discovery & Integration Checks

### Step 1: Eureka Registration Verification

```bash
# Check Eureka server for registered services
EUREKA_URL="https://$(oc get route naming-server-new -n cf-dev -o jsonpath='{.spec.host}')"
curl -k "$EUREKA_URL/eureka/apps" | xmllint --format -

# Check if API Gateway is registered
curl -k "$EUREKA_URL/eureka/apps/APIGATEWAY-APP" | xmllint --format -

# Verify API Gateway Eureka client logs
oc logs -l app=apigateway-app -n cf-dev | grep -i eureka
```

### Step 2: Spring Boot Admin Integration

```bash
# Check Spring Boot Admin for API Gateway registration
ADMIN_URL="https://$(oc get route spring-boot-admin -n cf-dev -o jsonpath='{.spec.host}')"
curl -k "$ADMIN_URL/instances" | jq '.[] | select(.registration.name=="apigateway-app")'

# Verify admin client logs
oc logs -l app=apigateway-app -n cf-dev | grep -i "admin"
```

---

## Part 5: API Gateway Functionality Tests

### Step 1: Health & Actuator Endpoints

```bash
# Get API Gateway URL
GATEWAY_URL="https://$(oc get route apigateway-app -n cf-dev -o jsonpath='{.spec.host}')"
echo "API Gateway URL: $GATEWAY_URL"

# Test health endpoint
curl -k "$GATEWAY_URL/actuator/health" | jq .

# Test info endpoint
curl -k "$GATEWAY_URL/actuator/info" | jq .

# Test gateway routes endpoint
curl -k "$GATEWAY_URL/actuator/gateway/routes" | jq .

# Test metrics endpoint
curl -k "$GATEWAY_URL/actuator/metrics" | jq .
```

### Step 2: Gateway Routing Tests

```bash
# Test routing to backend services (if available)
curl -k "$GATEWAY_URL/excel/actuator/health"
curl -k "$GATEWAY_URL/interviews/actuator/health"
curl -k "$GATEWAY_URL/placements/actuator/health"

# Test gateway filters
curl -k -H "X-Request-ID: test-123" "$GATEWAY_URL/actuator/health" -v
```

### Step 3: Load Balancing Verification

```bash
# Test multiple requests to verify load balancing
for i in {1..10}; do
  curl -k "$GATEWAY_URL/actuator/info" -s | jq -r '.hostname // "N/A"'
done
```

---

## Part 6: Performance & Resource Monitoring

### Step 1: Resource Usage

```bash
# Check CPU and memory usage
oc top pods -l app=apigateway-app -n cf-dev

# View resource limits and requests
oc describe pod -l app=apigateway-app -n cf-dev | grep -A 10 "Limits\|Requests"
```

### Step 2: Application Metrics

```bash
# Get JVM metrics
curl -k "$GATEWAY_URL/actuator/metrics/jvm.memory.used" | jq .

# Get HTTP request metrics
curl -k "$GATEWAY_URL/actuator/metrics/http.server.requests" | jq .

# Get gateway metrics
curl -k "$GATEWAY_URL/actuator/metrics/spring.cloud.gateway.requests" | jq .
```

---

## Part 7: Troubleshooting & Common Issues

### Issue 1: Pod Not Starting

```bash
# Check pod events
oc get events -n cf-dev --field-selector involvedObject.name=apigateway-app

# Check pod logs for startup errors
oc logs deployment/apigateway-app -n cf-dev --previous

# Check resource constraints
oc describe pod -l app=apigateway-app -n cf-dev | grep -A 15 "Conditions"

# Check image pull issues
oc describe pod -l app=apigateway-app -n cf-dev | grep -A 5 "Events"
```

### Issue 2: Eureka Registration Issues

```bash
# Check Eureka client configuration
oc exec -it deployment/apigateway-app -n cf-dev -- env | grep EUREKA

# Test connectivity to Eureka server
oc exec -it deployment/apigateway-app -n cf-dev -- curl -s http://naming-server-new:8761/eureka/apps

# Check DNS resolution
oc exec -it deployment/apigateway-app -n cf-dev -- nslookup naming-server-new
```

### Issue 3: Service Connectivity Issues

```bash
# Test internal service connectivity
oc run test-pod --image=curlimages/curl -it --rm -- sh
# Inside pod: curl http://apigateway-app.cf-dev.svc.cluster.local:8765/actuator/health

# Check service endpoints
oc get endpoints apigateway-app -n cf-dev -o yaml

# Verify network policies (if any)
oc get networkpolicy -n cf-dev
```

### Issue 4: Route Access Issues

```bash
# Check route configuration
oc get route apigateway-app -n cf-dev -o yaml

# Test route resolution
nslookup $(oc get route apigateway-app -n cf-dev -o jsonpath='{.spec.host}')

# Check certificate issues
openssl s_client -connect $(oc get route apigateway-app -n cf-dev -o jsonpath='{.spec.host}'):443 -servername $(oc get route apigateway-app -n cf-dev -o jsonpath='{.spec.host}')
```

---

## Part 8: Advanced Operations

### Rolling Updates

```bash
# Update image tag
helm upgrade cf-microservices helm-charts/cf-microservices \
  -n cf-dev \
  --set api-gateway.image.tag=new-version \
  --wait

# Monitor rolling update
oc rollout status deployment/apigateway-app -n cf-dev

# Rollback if needed
oc rollout undo deployment/apigateway-app -n cf-dev
```

### Scaling Operations

```bash
# Scale up replicas
helm upgrade cf-microservices helm-charts/cf-microservices \
  -n cf-dev \
  --set api-gateway.deployment.replicas=3 \
  --wait

# Verify scaling
oc get deployment apigateway-app -n cf-dev

# Test load distribution
for i in {1..20}; do curl -k "$GATEWAY_URL/actuator/info" -s >/dev/null && echo "Request $i completed"; done
```

### Configuration Updates

```bash
# Update environment variables
helm upgrade cf-microservices helm-charts/cf-microservices \
  -n cf-dev \
  --set-string api-gateway.deployment.env[0].name=LOGGING_LEVEL_ROOT \
  --set-string api-gateway.deployment.env[0].value=DEBUG \
  --wait

# Restart deployment to pick up config changes
oc rollout restart deployment/apigateway-app -n cf-dev
```

---

## Part 9: Monitoring & Observability

### Application Logs

```bash
# View application logs
oc logs deployment/apigateway-app -n cf-dev --tail=100 -f

# Search for specific patterns
oc logs deployment/apigateway-app -n cf-dev | grep -i "error\|exception\|warn"

# View logs from all replicas
oc logs -l app=apigateway-app -n cf-dev --tail=50
```

### Health Monitoring

```bash
# Continuous health monitoring
watch -n 5 "curl -k -s $GATEWAY_URL/actuator/health | jq '.status'"

# Check readiness and liveness probes
oc describe pod -l app=apigateway-app -n cf-dev | grep -A 5 "Liveness\|Readiness"
```

---

## Part 10: Cleanup Commands

### Remove API Gateway Only

```bash
# Scale down to zero
oc scale deployment apigateway-app --replicas=0 -n cf-dev

# Delete resources
oc delete deployment apigateway-app -n cf-dev
oc delete service apigateway-app -n cf-dev
oc delete route apigateway-app -n cf-dev
```

### Complete Cleanup

```bash
# Remove entire Helm release
helm uninstall cf-microservices -n cf-dev

# Verify cleanup
oc get all -l app=apigateway-app -n cf-dev
```

---

## Success Criteria Checklist

- [ ] Ansible playbook executes without errors
- [ ] Helm release shows as `deployed` status
- [ ] Deployment shows `2/2` ready replicas (or configured number)
- [ ] All pods are in `Running` state with `1/1` ready containers
- [ ] Service has proper ClusterIP and endpoints
- [ ] Route is accessible and returns HTTP 200
- [ ] Health endpoint returns `{"status": "UP"}`
- [ ] API Gateway registers with Eureka server
- [ ] Spring Boot Admin shows API Gateway as registered
- [ ] Gateway routes endpoint returns configured routes
- [ ] Environment variables are properly set
- [ ] Application logs show successful startup and Eureka registration
- [ ] Load balancing works across multiple replicas
- [ ] Gateway can route to backend services (when available)

---

## Integration Testing Script

```bash
#!/bin/bash
# API Gateway Integration Test Script

NAMESPACE="cf-dev"
GATEWAY_URL="https://$(oc get route apigateway-app -n $NAMESPACE -o jsonpath='{.spec.host}')"
EUREKA_URL="https://$(oc get route naming-server-new -n $NAMESPACE -o jsonpath='{.spec.host}')"

echo "=== API Gateway Integration Test ==="
echo "Gateway URL: $GATEWAY_URL"
echo "Eureka URL: $EUREKA_URL"

# Test 1: Health Check
echo -n "Testing health endpoint... "
HEALTH=$(curl -k -s "$GATEWAY_URL/actuator/health" | jq -r '.status')
if [ "$HEALTH" == "UP" ]; then
    echo "✓ PASSED"
else
    echo "✗ FAILED"
fi

# Test 2: Eureka Registration
echo -n "Testing Eureka registration... "
EUREKA_CHECK=$(curl -k -s "$EUREKA_URL/eureka/apps/APIGATEWAY-APP" | grep -c "apigateway-app")
if [ "$EUREKA_CHECK" -gt 0 ]; then
    echo "✓ PASSED"
else
    echo "✗ FAILED"
fi

# Test 3: Gateway Routes
echo -n "Testing gateway routes... "
ROUTES=$(curl -k -s "$GATEWAY_URL/actuator/gateway/routes" | jq -r '. | length')
if [ "$ROUTES" -gt 0 ]; then
    echo "✓ PASSED ($ROUTES routes configured)"
else
    echo "✗ FAILED"
fi

echo "=== Test Complete ==="
```

---

## Contact & Support

For issues or questions:
- Check application logs: `oc logs deployment/apigateway-app -n cf-dev`
- Review deployment events: `oc get events -n cf-dev`
- Verify Eureka registration: Check Eureka server dashboard
- Consult Spring Cloud Gateway documentation
- Contact DevOps team for infrastructure issues