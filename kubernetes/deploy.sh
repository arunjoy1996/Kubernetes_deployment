#!/usr/bin/env bash
set -e

# Define cluster name
CLUSTER_NAME="ml-app-cluster"

echo "=========================================="
echo "Creating Kind cluster: $CLUSTER_NAME"
echo "=========================================="
kind create cluster --config kubernetes/kind-config.yaml --name $CLUSTER_NAME

echo "=========================================="
echo "Building local Docker images..."
echo "=========================================="
docker build -t ml-api:latest .
docker build -t nginx-frontend:latest -f nginx/Dockerfile .

echo "=========================================="
echo "Loading Docker images into Kind cluster..."
echo "=========================================="
kind load docker-image ml-api:latest --name $CLUSTER_NAME
kind load docker-image nginx-frontend:latest --name $CLUSTER_NAME

echo "=========================================="
echo "Applying Kubernetes manifests..."
echo "=========================================="
kubectl apply -f kubernetes/ml-api.yaml
kubectl apply -f kubernetes/nginx.yaml
kubectl apply -f kubernetes/prometheus.yaml
kubectl apply -f kubernetes/loki.yaml
kubectl apply -f kubernetes/promtail.yaml
kubectl apply -f kubernetes/grafana.yaml
kubectl apply -f kubernetes/cadvisor.yaml

echo "=========================================="
echo "Installing Jenkins via Helm..."
echo "=========================================="
# Add Jenkins Helm Repo
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Install Jenkins
helm upgrade --install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  -f kubernetes/jenkins-values.yaml

# Apply ClusterRoleBinding for Jenkins
kubectl apply -f kubernetes/jenkins-rbac.yaml

echo "=========================================="
echo "Waiting for deployments to roll out..."
echo "=========================================="
kubectl rollout status deployment/ml-api
kubectl rollout status deployment/nginx
kubectl rollout status deployment/prometheus
kubectl rollout status deployment/loki
kubectl rollout status deployment/grafana
kubectl rollout status statefulset/jenkins -n jenkins

echo "=========================================="
echo "Setup complete! Access services at:"
echo "  - Frontend: http://localhost:80 (via http://127.0.0.1:80)"
echo "  - Grafana:  http://localhost:3000 (via http://127.0.0.1:3000)"
echo "  - Jenkins:  http://localhost:8080 (via http://127.0.0.1:8080)"
echo "=========================================="
