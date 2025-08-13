#!/bin/bash

set -e  # Stop on error

DEPLOY_DIR="oc-deploy"
LOG_FILE="terraform-run-$(date +'%Y%m%d-%H%M%S').log"
PLAN_OUT="tfplan.out"

echo "Moving to $DEPLOY_DIR directory..." | tee -a "$LOG_FILE"
cd "$DEPLOY_DIR"

echo "Running generate-dockerconfig.sh..." | tee -a "../$LOG_FILE"
chmod +x ./generate-dockerconfig.sh
./generate-dockerconfig.sh | tee -a "../$LOG_FILE"

echo "Running terraform init..." | tee -a "../$LOG_FILE"
terraform init | tee -a "../$LOG_FILE"

echo "Running terraform plan, output: $PLAN_OUT" | tee -a "../$LOG_FILE"
terraform plan -out="$PLAN_OUT" | tee -a "../$LOG_FILE"

echo "Running terraform apply with auto-approve..." | tee -a "../$LOG_FILE"
terraform apply -auto-approve "$PLAN_OUT" | tee -a "../$LOG_FILE"

echo "Terraform deployment completed successfully." | tee -a "../$LOG_FILE"
