# kubernetes/deploy.ps1
$ErrorActionPreference = "Stop"
$ClusterName = "ml-app-cluster"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Creating Kind cluster: $ClusterName" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
kind create cluster --config kubernetes/kind-config.yaml --name $ClusterName

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Building local Docker images..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
docker build -t ml-api:latest .
docker build -t nginx-frontend:latest -f nginx/Dockerfile .

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Loading Docker images into Kind cluster..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
kind load docker-image ml-api:latest --name $ClusterName
kind load docker-image nginx-frontend:latest --name $ClusterName

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Applying Kubernetes manifests..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
kubectl apply -f kubernetes/ml-api.yaml
kubectl apply -f kubernetes/nginx.yaml
kubectl apply -f kubernetes/prometheus.yaml
kubectl apply -f kubernetes/loki.yaml
kubectl apply -f kubernetes/promtail.yaml
kubectl apply -f kubernetes/grafana.yaml
kubectl apply -f kubernetes/cadvisor.yaml

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Installing Jenkins via Helm..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
# Add Jenkins Helm Repo
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Ensure the Docker Hub credentials secret exists for Jenkins
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

if ($env:DOCKER_HUB_USERNAME -and $env:DOCKER_HUB_PASSWORD) {
  kubectl create secret generic docker-hub-creds `
    --namespace jenkins `
    --from-literal=username=$env:DOCKER_HUB_USERNAME `
    --from-literal=password=$env:DOCKER_HUB_PASSWORD `
    --dry-run=client -o yaml | kubectl apply -f -
} else {
  kubectl create secret generic docker-hub-creds `
    --namespace jenkins `
    --from-literal=username='changeme' `
    --from-literal=password='changeme' `
    --dry-run=client -o yaml | kubectl apply -f -
}

# Install Jenkins
helm upgrade --install jenkins jenkins/jenkins `
  --namespace jenkins `
  --create-namespace `
  -f kubernetes/jenkins-values.yaml

# Apply ClusterRoleBinding for Jenkins
kubectl apply -f kubernetes/jenkins-rbac.yaml

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Waiting for deployments to roll out..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
kubectl rollout status deployment/ml-api
kubectl rollout status deployment/nginx
kubectl rollout status deployment/prometheus
kubectl rollout status deployment/loki
kubectl rollout status deployment/grafana
kubectl rollout status statefulset/jenkins -n jenkins

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Setup complete! Access services at:" -ForegroundColor Green
Write-Host "  - Frontend: http://localhost:80 (via http://127.0.0.1:80)" -ForegroundColor Green
Write-Host "  - Grafana:  http://localhost:3000 (via http://127.0.0.1:3000)" -ForegroundColor Green
Write-Host "  - Jenkins:  http://localhost:8080 (via http://127.0.0.1:8080)" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
