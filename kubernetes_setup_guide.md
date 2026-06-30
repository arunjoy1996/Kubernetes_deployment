# Kubernetes Migration Guide using Kind

**Kubernetes setup using Kind (Kubernetes in Docker) with 1 control-plane and 1 worker node**. 

Added the complete set of Kubernetes manifests and automation scripts under a new [kubernetes](file:///c:/Users/alexu/Documents/Squareroots.ai/Belden/Kubernetes%20Deployment/Deployment/kubernetes) directory:

- [kind-config.yaml](file:///c:/Users/alexu/Documents/Squareroots.ai/Belden/Kubernetes%20Deployment/Deployment/kubernetes/kind-config.yaml) — Cluster configuration
- [ml-api.yaml](file:///c:/Users/alexu/Documents/Squareroots.ai/Belden/Kubernetes%20Deployment/Deployment/kubernetes/ml-api.yaml) — Backend Deployment & Service mapping
- [nginx.yaml](file:///c:/Users/alexu/Documents/Squareroots.ai/Belden/Kubernetes%20Deployment/Deployment/kubernetes/nginx.yaml) — Frontend & Reverse Proxy
- [prometheus.yaml](file:///c:/Users/alexu/Documents/Squareroots.ai/Belden/Kubernetes%20Deployment/Deployment/kubernetes/prometheus.yaml) — Monitoring & Configuration
- [grafana.yaml](file:///c:/Users/alexu/Documents/Squareroots.ai/Belden/Kubernetes%20Deployment/Deployment/kubernetes/grafana.yaml) — Visualization & Datasources
- [loki.yaml](file:///c:/Users/alexu/Documents/Squareroots.ai/Belden/Kubernetes%20Deployment/Deployment/kubernetes/loki.yaml) — Log Aggregation storage
- [promtail.yaml](file:///c:/Users/alexu/Documents/Squareroots.ai/Belden/Kubernetes%20Deployment/Deployment/kubernetes/promtail.yaml) — Kubernetes Pod Log collection
- [cadvisor.yaml](file:///c:/Users/alexu/Documents/Squareroots.ai/Belden/Kubernetes%20Deployment/Deployment/kubernetes/cadvisor.yaml) — Container resource metrics
- [deploy.sh](file:///c:/Users/alexu/Documents/Squareroots.ai/Belden/Kubernetes%20Deployment/Deployment/kubernetes/deploy.sh) — Bash deployment automation
- [deploy.ps1](file:///c:/Users/alexu/Documents/Squareroots.ai/Belden/Kubernetes%20Deployment/Deployment/kubernetes/deploy.ps1) — PowerShell deployment automation

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
- **Jenkins CI/CD:** [http://localhost:8080](http://localhost:8080) (Log in with username `admin` and password `admin`)

---

## 🧑‍💻 Jenkins CI/CD Pipeline Setup

Jenkins is deployed automatically using the official Helm chart inside the `jenkins` namespace. It is configured to run stages inside dynamic Kubernetes agent pods.

### 1. Configure Docker Hub Credentials
Before triggering the pipeline (or before running the deployment scripts if you want the credentials ready immediately), create a Kubernetes Secret containing your Docker Hub credentials. Jenkins JCasC will automatically read this secret to configure the credentials in the Jenkins credentials store:

```bash
# Create the jenkins namespace if it doesn't exist yet
kubectl create namespace jenkins

# Create the docker-hub-creds secret
kubectl create secret generic docker-hub-creds \
  --namespace jenkins \
  --from-literal=username='YOUR_DOCKER_HUB_USERNAME' \
  --from-literal=password='YOUR_DOCKER_HUB_PASSWORD_OR_TOKEN'
```

### 2. How the Pipeline Works
The [Jenkinsfile](file:///c:/Users/alexu/Documents/Squareroots.ai/Belden/Kubernetes%20Deployment/Deployment_Jenkins/Jenkinsfile) is fully automated to run on a multi-container Kubernetes agent pod (`jenkins-agent`):
1. **`Test` Stage**: Runs inside a `python` container to install dependencies and execute `pytest` tests.
2. **`Build & Push` Stage**: Runs inside a `docker` container. It mounts the host's Docker socket to build the images using the host's Docker daemon, logs in to Docker Hub, and pushes them to your Docker Hub repository.
3. **`Deploy` Stage**: Runs inside a `kubectl` container. It dynamically updates the image references in the Kubernetes manifests (`ml-api.yaml` and `nginx.yaml`) with your Docker Hub username and applies them to the cluster.

### 3. Create the Jenkins Job
1. Open [http://localhost:8080](http://localhost:8080) and log in using:
   - **Username:** `admin`
   - **Password:** `admin`
2. Click on **New Item**.
3. Enter a name (e.g., `ml-pipeline`), select **Pipeline**, and click **OK**.
4. Scroll down to the **Pipeline** section:
   - **Definition:** Select **Pipeline script from SCM**.
   - **SCM:** Select **Git**.
   - **Repository URL:** Enter the path to your repository (or your remote Git URL).
   - **Branch Specifier:** Set to `*/main` (or whichever branch you are using).
   - **Script Path:** Ensure it is set to `Jenkinsfile`.
5. Click **Save** and then click **Build Now** to run the pipeline!

