#!/bin/bash

# Script to update all deployment templates to include imagePullSecrets

HELM_CHARTS_DIR="/Users/swaroop/Documents/FullStack-SRE/ConsultingFirm_infra/ROSA/ClaudeDoc/ansible/helm-charts/cf-microservices/charts"

# List of services to update (excluding already updated ones)
SERVICES=(
    "config-service"
    "spring-boot-admin" 
    "excel-service"
    "bench-profile"
    "daily-submissions"
    "interviews"
    "placements"
    "frontend"
)

echo "Updating deployment templates to include imagePullSecrets..."

for service in "${SERVICES[@]}"; do
    deployment_file="${HELM_CHARTS_DIR}/${service}/templates/deployment.yaml"
    
    if [[ -f "$deployment_file" ]]; then
        echo "Updating $service deployment template..."
        
        # Create backup
        cp "$deployment_file" "$deployment_file.backup"
        
        # Use sed to add imagePullSecrets after "spec:" line in template
        sed -i.tmp '/^    spec:$/,/^      containers:$/ {
            s/^    spec:$/&\
      {{- if .Values.global.imagePullSecrets }}\
      imagePullSecrets:\
        {{- toYaml .Values.global.imagePullSecrets | nindent 8 }}\
      {{- end }}/
        }' "$deployment_file"
        
        # Remove the temporary file created by sed
        rm "$deployment_file.tmp" 2>/dev/null || true
        
        echo "✅ Updated $service"
    else
        echo "❌ Deployment file not found for $service"
    fi
done

echo "✅ All deployment templates updated!"