#!/bin/bash

# Variables
AWS_REGION="us-east-1"
ECR_REGISTRY="818140567777.dkr.ecr.$AWS_REGION.amazonaws.com"
EMAIL="sonuk2911@gmail.com"
TFVARS_FILE="terraform.tfvars"

# Step 1: Login to ECR and create docker config file
aws ecr get-login-password --region $AWS_REGION | \
docker login --username AWS --password-stdin $ECR_REGISTRY

if [ $? -ne 0 ]; then
  echo "Docker login failed. Check AWS credentials and Docker status."
  exit 1
fi

echo "Logged in to ECR"

# Step 2: Create ~/.docker/config.json
DOCKER_CONFIG_JSON_PATH="$HOME/.docker/config.json"

if [ ! -f "$DOCKER_CONFIG_JSON_PATH" ]; then
  echo "$DOCKER_CONFIG_JSON_PATH not found. Docker login may have failed."
  exit 1
fi

# Step 3: Base64 encode the docker config
BASE64_ENCODED=$(base64 -w 0 "$DOCKER_CONFIG_JSON_PATH")

# Step 4: Update only the dockerconfigjson_base64 line in terraform.tfvars
if grep -q '^dockerconfigjson_base64' "$TFVARS_FILE"; then
  # Replace the line
  sed -i "s|^dockerconfigjson_base64 *=.*|dockerconfigjson_base64 = \"$BASE64_ENCODED\"|" "$TFVARS_FILE"
  echo "dockerconfigjson_base64 updated in $TFVARS_FILE"
else
  # Append the line
  echo "dockerconfigjson_base64 = \"$BASE64_ENCODED\"" >> "$TFVARS_FILE"
  echo "➕ dockerconfigjson_base64 added to $TFVARS_FILE"
fi

