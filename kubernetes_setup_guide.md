# Kubernetes Migration Guide using Kind

**Kubernetes setup using Kind (Kubernetes in Docker) with 1 control-plane and 1 worker node**. 

Added the complete set of Kubernetes manifests and automation scripts under a new [kubernetes] directory:

- [kind-config.yaml] — Cluster configuration
- [ml-api.yaml] — Backend Deployment & Service mapping
- [nginx.yaml] — Frontend & Reverse Proxy
- [prometheus.yaml] — Monitoring & Configuration
- [grafana.yaml] — Visualization & Datasources
- [loki.yaml] — Log Aggregation storage
- [promtail.yaml] — Kubernetes Pod Log collection
- [cadvisor.yaml] — Container resource metrics
- [deploy.sh] — Bash deployment automation
- [deploy.ps1] — PowerShell deployment automation

---

## 🏗️ Architectural Mapping: Docker Compose vs. Kubernetes

Here is how each Docker Compose component was translated into Kubernetes standards:

| Docker Compose Service | Kubernetes Resource Type | Translation Design |
| :--- | :--- | :--- |
| **`backend` (ml-api)** | `Deployment` + `Service` (ClusterIP) | Deploys backend API. Exposed internally as two services: `ml-api` (for Prometheus) and `backend` (for Nginx) to preserve existing config names. |
| **`nginx`** | `Deployment` + `Service` (NodePort) | Deploys Nginx container with static frontend baked in. Port `80` is exposed as a NodePort (`30080`), mapped directly to host port `80` via Kind. |
| **`prometheus`** | `Deployment` + `ConfigMap` + `PVC` | Raw `prometheus.yml` configuration is injected as a `ConfigMap`. Scrapes metric targets using Kubernetes local DNS. Data persists via a `PersistentVolumeClaim`. |
| **`grafana`** | `Deployment` + `ConfigMap` + `PVC` | Provisioned datasources (Loki & Prometheus) are loaded via a `ConfigMap`. Dashboard configuration and settings persist in a `PVC`. |
| **`loki`** | `Deployment` + `ConfigMap` + `PVC` | Deploys Loki. Local log storage is backed by a `PVC` with customized `fsGroup` permissions. |
| **`promtail`** | `DaemonSet` + `ConfigMap` + `RBAC` | Unlike Docker Compose, Promtail runs as a `DaemonSet` on every node to scrape `/var/log/pods` directory. Configured with a `ServiceAccount` and `ClusterRole` to fetch pod metadata from the API server. |
| **`cadvisor`** | `DaemonSet` + `Service` | Runs on every node to mount host root paths (`/sys`, `/var/run`, `/var/lib/docker`) to expose container-level resource statistics to Prometheus. |

---

## ⚙️ Key Kubernetes & Kind Adaptations

### 1. Host Port Access with Kind Port Mapping
Since Kubernetes runs inside containerized nodes under Kind, standard Service ports aren't automatically reachable on your local Windows host. We solve this by adding `extraPortMappings` to the **control-plane** node in `kind-config.yaml`:
```yaml
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080  # NodePort of Nginx Service
    hostPort: 80          # Accessible on host at http://localhost
  - containerPort: 30300  # NodePort of Grafana Service
    hostPort: 3000        # Accessible on host at http://localhost:3000
- role: worker
```

### 2. Log Scrape configuration for Promtail
In Docker Compose, Promtail watched the host Docker socket (`/var/run/docker.sock`). In Kubernetes, logs are collected from the node's standard pod path (`/var/log/pods/*/*/*.log`). The `promtail.yaml` includes a custom `scrape_config` that translates pod metadata (labels like `app` and `service`) into Loki indexing labels.

### 3. Persistent Volumes
Docker Compose volume definitions (`grafana-data`, `prometheus-data`, `loki-data`) are mapped to Kubernetes **PersistentVolumeClaims (PVCs)**. Kind cluster nodes use the default local-path provisioner to automatically bind these PVCs to directories on the nodes.

---

## 🚀 How to Run the Kubernetes Setup

> [!IMPORTANT]
> Ensure **Docker Desktop** (or Docker daemon) is running and the `kind` and `kubectl` CLIs are installed.

### Using Bash (WSL, Git Bash, macOS/Linux)
1. Make the script executable:
   ```bash
   chmod +x kubernetes/deploy.sh
   ```
2. Run the deployment:
   ```bash
   ./kubernetes/deploy.sh
   ```

### Using PowerShell (Windows Native)
1. Run the script:
   ```powershell
   .\kubernetes\deploy.ps1
   ```

Once deployed, the scripts will wait for all Pods to become healthy. You will be able to access:
- **Web App UI:** [http://localhost](http://localhost)
- **Grafana Dashboard:** [http://localhost:3000](http://localhost:3000)
