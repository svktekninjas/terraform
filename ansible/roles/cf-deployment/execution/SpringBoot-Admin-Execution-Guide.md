# Spring Boot Admin Service - Execution Guide
## Complete Ansible Playbook Instructions & Validation Steps

This guide provides step-by-step instructions for deploying Spring Boot Admin service using Ansible playbooks, including comprehensive validation of deployments, pods, services, and routes.

---

## Prerequisites

- Ansible installed with kubernetes.core collection
- OpenShift CLI (oc) installed and configured
- Access to OpenShift cluster with proper permissions
- ECR credentials configured for image pulling
- Helm charts directory structure in place

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
```

### Step 2: Verify Ansible Structure

```bash
# Navigate to ansible directory
cd /path/to/ansible

# Verify role structure
ls -la roles/cf-deployment/
ls -la helm-charts/cf-microservices/charts/spring-boot-admin/

# Check playbook exists
ls -la playbooks/main.yml
```

---

## Part 2: Spring Boot Admin Deployment

### Method 1: Deploy Spring Boot Admin Only

```bash
# Deploy only Spring Boot Admin service
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_spring_boot_admin_only=true" \
  -e "environment=dev" \
  -e "spring_boot_admin_env_vars=[
    {'name': 'SERVER_PORT', 'value': '8082'},
    {'name': 'SPRING_PROFILES_ACTIVE', 'value': 'openshift'},
    {'name': 'MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE', 'value': 'health,info,metrics,env'},
    {'name': 'MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS', 'value': 'always'}
  ]"
```

### Method 2: Deploy with Custom Configuration

```bash
# Deploy with advanced configuration
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "deploy_spring_boot_admin_only=true" \
  -e "environment=dev" \
  -e "helm_release_name=spring-boot-admin" \
  -e "helm_chart_path=helm-charts/cf-microservices" \
  -e "spring_boot_admin_replicas=1" \
  -e "spring_boot_admin_cpu_limit=500m" \
  -e "spring_boot_admin_memory_limit=512Mi" \
  -e "spring_boot_admin_env_vars=[
    {'name': 'SERVER_PORT', 'value': '8082'},
    {'name': 'SPRING_PROFILES_ACTIVE', 'value': 'openshift'},
    {'name': 'LOGGING_LEVEL_ROOT', 'value': 'INFO'},
    {'name': 'MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE', 'value': 'health,info,metrics,env,loggers'},
    {'name': 'MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS', 'value': 'always'},
    {'name': 'SPRING_BOOT_ADMIN_UI_TITLE', 'value': 'ConsultingFirm Admin Dashboard'}
  ]"
```

### Method 3: Deploy with Full Microservices Stack

```bash
# Deploy all services including Spring Boot Admin
ansible-playbook playbooks/main.yml \
  -t cf-deployment \
  -e "environment=dev" \
  -e "deploy_all_services=true"
```

---

## Part 3: Deployment Validation & Verification

### Step 1: Verify Helm Release

```bash
# Check Helm release status
helm list -n cf-dev

# Get Helm release details
helm status cf-microservices -n cf-dev

# View Helm release history
helm history cf-microservices -n cf-dev
```

Expected Output:
```
NAME                NAMESPACE   REVISION    UPDATED                                 STATUS      CHART                       APP VERSION
cf-microservices    cf-dev      1           2024-01-XX XX:XX:XX.XXXXXXX +0000 UTC  deployed    cf-microservices-0.1.0      1.0.0
```

### Step 2: Validate Deployment

```bash
# Check deployment status
oc get deployment spring-boot-admin -n cf-dev

# View deployment details
oc describe deployment spring-boot-admin -n cf-dev

# Check replica status
oc get rs -l app=spring-boot-admin -n cf-dev
```

Expected Output:
```
NAME                READY   UP-TO-DATE   AVAILABLE   AGE
spring-boot-admin   1/1     1            1           2m30s
```

### Step 3: Validate Pods

```bash
# Check pod status
oc get pods -l app=spring-boot-admin -n cf-dev

# View pod details
oc describe pod -l app=spring-boot-admin -n cf-dev

# Check pod logs
oc logs -l app=spring-boot-admin -n cf-dev --tail=50

# Monitor pod startup
oc get pods -l app=spring-boot-admin -n cf-dev -w
```

Expected Output:
```
NAME                                 READY   STATUS    RESTARTS   AGE
spring-boot-admin-xxxxxxxxxx-xxxxx   1/1     Running   0          2m15s
```

### Step 4: Validate Service

```bash
# Check service status
oc get svc spring-boot-admin -n cf-dev

# View service details
oc describe svc spring-boot-admin -n cf-dev

# Test service connectivity
oc get endpoints spring-boot-admin -n cf-dev
```

Expected Output:
```
NAME                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
spring-boot-admin   ClusterIP   172.30.xxx.xxx   <none>        8082/TCP   2m45s
```

### Step 5: Validate Route

```bash
# Check route status
oc get route spring-boot-admin -n cf-dev

# View route details
oc describe route spring-boot-admin -n cf-dev

# Test route accessibility
curl -k https://$(oc get route spring-boot-admin -n cf-dev -o jsonpath='{.spec.host}')/actuator/health
```

Expected Output:
```
NAME                HOST/PORT                                           PATH   SERVICES            PORT   TERMINATION   WILDCARD
spring-boot-admin   spring-boot-admin-cf-dev.apps.cluster.domain.com          spring-boot-admin   8082   edge          None
```

---

## Part 4: Health & Functionality Checks

### Step 1: Application Health Check

```bash
# Get route URL
ADMIN_URL="https://$(oc get route spring-boot-admin -n cf-dev -o jsonpath='{.spec.host}')"
echo "Spring Boot Admin URL: $ADMIN_URL"

# Check health endpoint
curl -k "$ADMIN_URL/actuator/health" | jq .

# Check info endpoint
curl -k "$ADMIN_URL/actuator/info" | jq .

# Check metrics endpoint
curl -k "$ADMIN_URL/actuator/metrics" | jq .
```

### Step 2: Web UI Accessibility

```bash
# Test web interface
curl -k -I "$ADMIN_URL"

# Check login page
curl -k "$ADMIN_URL/login" -s -o /dev/null -w "%{http_code}"
```

Expected Response: `200` or `302`

### Step 3: Environment Variables Verification

```bash
# Check environment variables in pod
oc exec -it deployment/spring-boot-admin -n cf-dev -- env | grep -E "(SERVER_PORT|SPRING_PROFILES_ACTIVE|MANAGEMENT)"

# Verify port configuration
oc exec -it deployment/spring-boot-admin -n cf-dev -- netstat -tlnp | grep 8082
```

---

## Part 5: Troubleshooting & Common Issues

### Issue 1: Pod Not Starting

```bash
# Check pod events
oc get events -n cf-dev --field-selector involvedObject.name=spring-boot-admin

# Check pod logs for errors
oc logs deployment/spring-boot-admin -n cf-dev --previous

# Check resource constraints
oc describe pod -l app=spring-boot-admin -n cf-dev | grep -A 10 "Conditions"
```

### Issue 2: Service Connection Issues

```bash
# Test service internally
oc run test-pod --image=curlimages/curl -it --rm -- sh
# Inside pod: curl http://spring-boot-admin.cf-dev.svc.cluster.local:8082/actuator/health

# Check service endpoints
oc get endpoints spring-boot-admin -n cf-dev -o yaml
```

### Issue 3: Route Access Issues

```bash
# Check route configuration
oc get route spring-boot-admin -n cf-dev -o yaml

# Test route resolution
nslookup $(oc get route spring-boot-admin -n cf-dev -o jsonpath='{.spec.host}')

# Check TLS certificate
openssl s_client -connect $(oc get route spring-boot-admin -n cf-dev -o jsonpath='{.spec.host}'):443 -servername $(oc get route spring-boot-admin -n cf-dev -o jsonpath='{.spec.host}')
```

---

## Part 6: Monitoring & Maintenance

### Rolling Updates

```bash
# Update image tag
helm upgrade cf-microservices helm-charts/cf-microservices \
  -n cf-dev \
  --set spring-boot-admin.image.tag=new-version \
  --wait

# Monitor rolling update
oc rollout status deployment/spring-boot-admin -n cf-dev
```

### Scaling Operations

```bash
# Scale up replicas
helm upgrade cf-microservices helm-charts/cf-microservices \
  -n cf-dev \
  --set spring-boot-admin.deployment.replicas=2 \
  --wait

# Verify scaling
oc get deployment spring-boot-admin -n cf-dev
```

### Backup Configuration

```bash
# Export current configuration
oc get deployment spring-boot-admin -n cf-dev -o yaml > spring-boot-admin-deployment-backup.yaml
oc get service spring-boot-admin -n cf-dev -o yaml > spring-boot-admin-service-backup.yaml
oc get route spring-boot-admin -n cf-dev -o yaml > spring-boot-admin-route-backup.yaml
```

---

## Part 7: Integration Verification

### Check Registration with Other Services

```bash
# Verify API Gateway can reach Spring Boot Admin
oc exec -it deployment/apigateway-app -n cf-dev -- curl -s http://spring-boot-admin:8082/actuator/health

# Check if services are registering with Spring Boot Admin
curl -k "$ADMIN_URL/instances" | jq .
```

---

## Part 8: Cleanup Commands

### Remove Spring Boot Admin Only

```bash
# Delete Spring Boot Admin deployment
oc delete deployment spring-boot-admin -n cf-dev
oc delete service spring-boot-admin -n cf-dev
oc delete route spring-boot-admin -n cf-dev
```

### Complete Cleanup

```bash
# Remove entire Helm release
helm uninstall cf-microservices -n cf-dev

# Verify cleanup
oc get all -l app=spring-boot-admin -n cf-dev
```

---

## Success Criteria Checklist

- [ ] Ansible playbook executes without errors
- [ ] Helm release shows as `deployed` status
- [ ] Deployment shows `1/1` ready replicas
- [ ] Pod is in `Running` state with `1/1` ready containers
- [ ] Service has proper ClusterIP and endpoints
- [ ] Route is accessible and returns HTTP 200/302
- [ ] Health endpoint returns `{"status": "UP"}`
- [ ] Web UI is accessible through route
- [ ] Environment variables are properly set
- [ ] Application logs show successful startup
- [ ] Integration with other services works properly

---

## Contact & Support

For issues or questions:
- Check application logs: `oc logs deployment/spring-boot-admin -n cf-dev`
- Review deployment events: `oc get events -n cf-dev`
- Consult Spring Boot Admin documentation
- Contact DevOps team for infrastructure issues