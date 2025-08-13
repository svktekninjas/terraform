#!/bin/bash

set -e

DEPLOY_DIR="oc-deploy"

cd "$DEPLOY_DIR"

echo "Running terraform destroy..."
terraform destroy -auto-approve

echo "Terraform destroy completed successfully."
