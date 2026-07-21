#!/bin/bash -e

DOCKER_IMAGE=$1
IDENTITY_ID=$2
ACR_NAME=$3
QUOTE_SERVICE_URL=$4
NEWSFEED_SERVICE_URL=$5
STATIC_URL=$6


curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "Provisioning docker image $DOCKER_IMAGE"

# cleanup previous deployment
sudo docker stop front_end || true
sudo docker rm front_end || true

sudo az login --identity --username $IDENTITY_ID

sudo az acr login --name $ACR_NAME

sudo docker pull $DOCKER_IMAGE

NEWSFEED_SECRET_TOKEN="T1&eWbYXNWG1w1^YGKDPxAWJ@^et^&kX"

sudo docker run -d \
  --restart always \
  --name front_end \
  -e QUOTE_SERVICE_URL=${QUOTE_SERVICE_URL} \
  -e NEWSFEED_SERVICE_URL=${NEWSFEED_SERVICE_URL} \
  -e STATIC_URL=${STATIC_URL} \
  -e NEWSFEED_SERVICE_TOKEN=${NEWSFEED_SECRET_TOKEN} \
  -p 8080:8080 \
  $DOCKER_IMAGE

