#!/bin/bash

aws ecr get-login-password --region ${ECR_REGISTRY_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY_URL}

# Docker Build Sender Image
docker build -t ${ECR_REGISTRY_URL}:${TAG} ${DOCKERFILE_PATH}
docker push ${ECR_REGISTRY_URL}:${TAG}