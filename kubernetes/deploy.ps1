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
Write-Host "Waiting for deployments to roll out..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
kubectl rollout status deployment/ml-api
kubectl rollout status deployment/nginx
kubectl rollout status deployment/prometheus
kubectl rollout status deployment/loki
kubectl rollout status deployment/grafana

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Setup complete! Access services at:" -ForegroundColor Green
Write-Host "  - Frontend: http://localhost:80 (via http://127.0.0.1:80)" -ForegroundColor Green
Write-Host "  - Grafana:  http://localhost:3000 (via http://127.0.0.1:3000)" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
