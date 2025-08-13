# Helm Commands Reference Guide

## 🔍 View Helm Chart Contents Without Deploying

### 1. See All Resources That Would Be Created
```bash
helm template cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev
```

### 2. See Only Deployments
```bash
helm template cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev | grep "kind: Deployment" -A 5
```

### 3. See Deployment Names and Replicas
```bash
helm template cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev | grep -E "(kind: Deployment|name: |replicas: )"
```

### 4. See All Services
```bash
helm template cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev | grep "kind: Service" -A 3
```

### 5. See All Routes
```bash
helm template cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev | grep "kind: Route" -A 3
```

## 📋 Check Current Deployments

### 6. List Current Helm Releases
```bash
helm list -n cf-dev
```

### 7. See Current Deployment Status
```bash
oc get deployments -n cf-dev
```

### 8. See All Pods
```bash
oc get pods -n cf-dev
```

### 9. Check Specific Microservice
```bash
# Replace "bench" with any service name
oc get pods -n cf-dev | grep bench
oc get deployments -n cf-dev | grep bench
```

## 🔧 Helm Management Commands

### 10. Dry Run (See What Would Change)
```bash
helm upgrade cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev --dry-run
```

### 11. Show Current Helm Values
```bash
helm get values cf-microservices-dev -n cf-dev
```

### 12. Show Helm Release History
```bash
helm history cf-microservices-dev -n cf-dev
```

### 13. Show Helm Release Notes
```bash
helm get notes cf-microservices-dev -n cf-dev
```

## 🎯 Microservice-Specific Commands

### 14. Check Database-Connected Services
```bash
oc get pods -n cf-dev | grep -E "(bench|daily|interviews|placements)"
```

### 15. Check Environment Variables for Database Config
```bash
# Check any pod's database configuration
oc get pod <POD-NAME> -n cf-dev -o jsonpath='{.spec.containers[0].env[?(@.name=="SPRING_DATASOURCE_URL")].value}'
oc get pod <POD-NAME> -n cf-dev -o jsonpath='{.spec.containers[0].env[?(@.name=="SPRING_DATASOURCE_PASSWORD")].value}'

# Example:
oc get pod bench-profile-service-77659b4dc7-8gw66 -n cf-dev -o jsonpath='{.spec.containers[0].env[?(@.name=="SPRING_DATASOURCE_PASSWORD")].value}'
```

### 16. View Specific Values Files
```bash
# View individual microservice configurations
cat helm-charts/cf-microservices/charts/bench-profile/values.yaml
cat helm-charts/cf-microservices/charts/daily-submissions/values.yaml
cat helm-charts/cf-microservices/values.yaml  # Main values file
```

## 📊 Monitor After Changes

### 17. Watch Deployment Rollout
```bash
oc rollout status deployment/bench-profile-service -n cf-dev
```

### 18. View Logs
```bash
oc logs -f deployment/bench-profile-service -n cf-dev
```

### 19. Restart Deployment
```bash
oc rollout restart deployment/bench-profile-service -n cf-dev
```

## 📈 Tabular Output Commands

### Basic Table with awk
```bash
helm template cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev | \
grep "kind: Deployment" -A 5 | \
awk '/kind: Deployment/{kind=$2} /name:/{if(kind=="Deployment") name=$2} /namespace:/{ns=$2} /app:/{app=$2; print name "\t" ns "\t" app; kind=""}'
```

### Enhanced Table with Headers
```bash
echo -e "DEPLOYMENT_NAME\tNAMESPACE\tAPP_LABEL" && \
helm template cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev | \
grep "kind: Deployment" -A 5 | \
awk '/kind: Deployment/{kind=$2} /name:/{if(kind=="Deployment") name=$2} /namespace:/{ns=$2} /app:/{app=$2; print name "\t" ns "\t" app; kind=""}'
```

### Formatted Table with column
```bash
echo -e "DEPLOYMENT_NAME\tNAMESPACE\tAPP_LABEL" && \
helm template cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev | \
grep "kind: Deployment" -A 5 | \
awk '/kind: Deployment/{kind=$2} /name:/{if(kind=="Deployment") name=$2} /namespace:/{ns=$2} /app:/{app=$2; print name "\t" ns "\t" app; kind=""}' | \
column -t
```

### Pretty Table with Borders
```bash
{
  echo "| DEPLOYMENT NAME | NAMESPACE | APP LABEL |"
  echo "|-----------------|-----------|-----------|"
  helm template cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev | \
  grep "kind: Deployment" -A 5 | \
  awk '/kind: Deployment/{kind=$2} /name:/{if(kind=="Deployment") name=$2} /namespace:/{ns=$2} /app:/{app=$2; print "| " name " | " ns " | " app " |"; kind=""}'
}
```

### Numbered Table
```bash
{
  echo -e "# \tDEPLOYMENT_NAME\tNAMESPACE\tAPP_LABEL"
  helm template cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev | \
  grep "kind: Deployment" -A 5 | \
  awk '/kind: Deployment/{kind=$2} /name:/{if(kind=="Deployment") name=$2} /namespace:/{ns=$2} /app:/{app=$2; print ++i "\t" name "\t" ns "\t" app; kind=""}'
} | column -t
```

### CSV Format
```bash
echo "deployment_name,namespace,app_label" && \
helm template cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev | \
grep "kind: Deployment" -A 5 | \
awk '/kind: Deployment/{kind=$2} /name:/{if(kind=="Deployment") name=$2} /namespace:/{ns=$2} /app:/{app=$2; print name "," ns "," app; kind=""}'
```

### One-liner Simple Table
```bash
helm template cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev | grep -E "(kind: Deployment|name:|namespace:|app:)" | paste - - - - | awk '{print $4 "\t" $6 "\t" $8}' | column -t
```

### Most Practical Command (Recommended)
```bash
printf "%-30s %-10s %-30s\n" "DEPLOYMENT_NAME" "NAMESPACE" "APP_LABEL" && \
printf "%-30s %-10s %-30s\n" "$(printf '%*s' 30 | tr ' ' '-')" "$(printf '%*s' 10 | tr ' ' '-')" "$(printf '%*s' 30 | tr ' ' '-')" && \
helm template cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev | \
grep "kind: Deployment" -A 5 | \
awk '/kind: Deployment/{kind=$2} /name:/{if(kind=="Deployment") name=$2} /namespace:/{ns=$2} /app:/{app=$2; printf "%-30s %-10s %-30s\n", name, ns, app; kind=""}'
```

## 🚀 Common Operations

### Upgrade with Database Configuration
```bash
helm upgrade cf-microservices-dev helm-charts/cf-microservices \
  --namespace cf-dev \
  --set benchProfile.database.password=svktekdbdev
```

### Rollback to Previous Version
```bash
helm rollback cf-microservices-dev -n cf-dev
```

### Delete Release (⚠️ Dangerous)
```bash
helm uninstall cf-microservices-dev -n cf-dev
```

### Install Fresh Release
```bash
helm install cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev
```

## 🔍 Troubleshooting Commands

### Check Pod Status
```bash
# All pods
oc get pods -n cf-dev

# Specific service
oc get pods -n cf-dev -l app=bench-profile-service

# With wide output
oc get pods -n cf-dev -o wide
```

### Describe Pod for Detailed Info
```bash
oc describe pod <pod-name> -n cf-dev
```

### Check Events
```bash
oc get events -n cf-dev --sort-by='.lastTimestamp'
```

### Check Service Endpoints
```bash
oc get endpoints -n cf-dev
```

### Check Ingress/Routes
```bash
oc get routes -n cf-dev
```

---
*Last Updated: July 30, 2025*
*Environment: cf-dev*
*Helm Release: cf-microservices-dev*