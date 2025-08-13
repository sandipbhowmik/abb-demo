# Deploying PetClinic to AKS with Helm
This README explains how to deploy the application to **Azure Kubernetes Service (AKS)** using a **Helm chart** that includes:
- **Scaling**: resources, Horizontal Pod Autoscaler (HPA), PodDisruptionBudget (PDB), optional Vertical Pod Autoscaler (VPA).
- **Secret management**: either **Kubernetes Secrets** or **Azure Key Vault** via **Secrets Store CSI Driver** + **Azure Workload Identity**.

> The chart is written to be **service-agnostic** (it can deploy any microservice). Deploy each service (e.g., `api-gateway`, `customers-service`) as a separate Helm _release_ with its own values file.

---

## 1) Prerequisites

- An AKS cluster with:
  - Access configured on your machine: `az aks get-credentials -g <rg> -n <aks-name>`
  - **Metrics Server** installed (required for HPA).
  - **AcrPull** permission from AKS to your ACR (image pulls).
- If using **Azure Key Vault** mode:
  - **OIDC/Workload Identity** enabled on AKS.
  - **Secrets Store CSI Driver** and **Azure Key Vault provider** installed cluster-wide.
  - A **User-Assigned Managed Identity (UAMI)** with **Key Vault Secrets User** on the target vault.
  - A Federated Identity Credential that binds `system:serviceaccount:apps:petclinic-sa` to the UAMI.
- Helm 3.12+ and kubectl 1.27+ on your workstation.

Create namespace:
```bash
kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -
```

---

## 2) Chart Layout (generic microservice chart)
```
charts/microservice/
  Chart.yaml
  values.yaml                  # defaults
  templates/
    deployment.yaml
    service.yaml
    hpa.yaml
    pdb.yaml
    vpa.yaml                   # optional (enabled by values)
    serviceaccount.yaml
    secret.yaml                # used when secrets.mode = "k8s"
    csi-secretproviderclass.yaml  # used when secrets.mode = "akv"
```

---

## 3) Quick Start (two secret modes)
### Option A — Using **Kubernetes Secrets**
1) Create or update a Kubernetes Secret with required keys (example: DB creds):
```bash
kubectl -n apps create secret generic petclinic-db --from-literal=DB_USERNAME=pet \
                                                  --from-literal=DB_PASSWORD='S3cr3t!' \
                                                  --dry-run=client -o yaml | kubectl apply -f -
```

2) Prepare a values file (e.g., `values-api-gateway.yaml`):
```yaml
nameOverride: api-gateway
namespace: apps

image:
  repository: abbdemoazdevacr.azurecr.io/demo-petclinic-app/api-gateway
  tag: "sha-<git-sha>"   # or "1.0.0"
  pullPolicy: IfNotPresent

serviceAccount:
  create: true
  name: petclinic-sa

resources:
  requests: { cpu: "200m", memory: "256Mi" }
  limits:   { cpu: "500m", memory: "512Mi" }

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 6
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

pdb:
  enabled: true
  minAvailable: 1

vpa:
  enabled: false

secrets:
  mode: "k8s"
  k8s:
    envFromSecretNames:
      - petclinic-db
  env:
    - name: SPRING_PROFILES_ACTIVE
      value: "prod"

service:
  type: ClusterIP
  port: 8080

container:
  port: 8080
  livenessProbe:
    httpGet: { path: /actuator/health/liveness, port: 8080 }
    initialDelaySeconds: 20
    periodSeconds: 10
  readinessProbe:
    httpGet: { path: /actuator/health/readiness, port: 8080 }
    initialDelaySeconds: 10
    periodSeconds: 5
```

3) Install:
```bash
helm upgrade --install api-gateway charts/microservice \
  -n apps -f values-api-gateway.yaml
```

---

### Option B — Using **Azure Key Vault** via Secrets Store CSI + Workload Identity
> Secrets are mounted as **ephemeral files** inside the pod (and optionally synced to a native K8s Secret for env vars).

1) Ensure cluster prerequisites for **Workload Identity** and **Secrets Store CSI** are installed and the UAMI has KV access.

2) Prepare a values file (e.g., `values-customers.yaml`):
```yaml
nameOverride: customers-service
namespace: apps

image:
  repository: abbdemoazdevacr.azurecr.io/demo-petclinic-app/customers-service
  tag: "sha-<git-sha>"
  pullPolicy: IfNotPresent

serviceAccount:
  create: true
  name: petclinic-sa
  annotations:
    azure.workload.identity/use: "true"
    azure.workload.identity/client-id: "<UAMI-CLIENT-ID>"

resources:
  requests: { cpu: "200m", memory: "256Mi" }
  limits:   { cpu: "500m", memory: "512Mi" }

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 8
  targetCPUUtilizationPercentage: 70

pdb:
  enabled: true
  minAvailable: 1

vpa:
  enabled: false

secrets:
  mode: "akv"
  akv:
    vaultName: "<your-kv-name>"
    tenantId: "<your-tenant-id>"
    objects:
      - name: "db-username"   # how it will be exposed inside the mount path
        objectName: "petclinic-db-username"   # actual KV secret name
        type: "secret"
      - name: "db-password"
        objectName: "petclinic-db-password"
        type: "secret"
    mountPath: "/mnt/secrets-store"
    syncKubernetesSecrets: true
    secretObjects:
      - secretName: "petclinic-db"
        type: Opaque
        data:
          - key: DB_USERNAME
            objectName: db-username
          - key: DB_PASSWORD
            objectName: db-password

env:
  # Option A: Use synced Kubernetes Secret
  - name: DB_USERNAME
    valueFrom:
      secretKeyRef: { name: petclinic-db, key: DB_USERNAME }
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef: { name: petclinic-db, key: DB_PASSWORD }

  # Option B: Read from mounted files (if not syncing to K8s Secret)
  # - name: DB_PASSWORD_FILE
  #   value: "/mnt/secrets-store/db-password"

service:
  type: ClusterIP
  port: 8081

container:
  port: 8081
  livenessProbe:
    httpGet: { path: /actuator/health/liveness, port: 8081 }
    initialDelaySeconds: 20
    periodSeconds: 10
  readinessProbe:
    httpGet: { path: /actuator/health/readiness, port: 8081 }
    initialDelaySeconds: 10
    periodSeconds: 5
```

3) Install:
```bash
helm upgrade --install customers charts/microservice \
  -n apps -f values-customers.yaml
```

---
## 4) Scaling Configurations

### 4.1 Resource Requests & Limits
- Always set `resources.requests` and `resources.limits` for CPU/Memory.
- HPA uses metrics from requests/usage; without requests, autoscaling is ineffective.

### 4.2 Horizontal Pod Autoscaler (HPA)
Values:
```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 8
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```
Notes:
- Requires **Metrics Server**.
- Use both CPU and Memory targets where meaningful.
- Start with conservative min/max; observe and iterate.

### 4.3 PodDisruptionBudget (PDB)
Values:
```yaml
pdb:
  enabled: true
  minAvailable: 1   # or maxUnavailable: 1
```
Notes:
- Protects availability during voluntary disruptions (node drains, upgrades).
- Tune `minAvailable` based on min replicas and SLOs.

### 4.4 Vertical Pod Autoscaler (VPA) (optional)
Values:
```yaml
vpa:
  enabled: false
  updatePolicy: "Off"   # "Off" | "Initial" | "Auto"
```
Notes:
- VPA and HPA can coexist if VPA is in **recommendation** mode.
- Start with `enabled: false`; evaluate with caution in production.

---

## 5) Secret Management

### 5.1 Kubernetes Secrets (simple)
- Create a native Secret and expose via `envFromSecretNames` (whole secret) or `env` with `valueFrom.secretKeyRef`.
- Keep secrets out of Git. Use CI/CD or `kubectl create secret` at deploy time.
- Example values:
```yaml
secrets:
  mode: "k8s"
  k8s:
    envFromSecretNames: [ "petclinic-db" ]
```

### 5.2 Azure Key Vault via CSI + Workload Identity
- No long-lived credentials inside cluster; pods authenticate via **Workload Identity** using SA → OIDC → UAMI.
- Two consumption options:
  1) **Mounted files** under `mountPath` (ephemeral, not persisted to etcd).
  2) **Sync to Kubernetes Secret** (`syncKubernetesSecrets: true`) to use `envFrom` or `secretKeyRef`.
- Example values:
```yaml
secrets:
  mode: "akv"
  akv:
    vaultName: "<kv-name>"
    tenantId: "<tenant-id>"
    objects:
      - name: db-password
        objectName: petclinic-db-password
        type: secret
    mountPath: "/mnt/secrets-store"
    syncKubernetesSecrets: true
    secretObjects:
      - secretName: petclinic-db
        type: Opaque
        data:
          - key: DB_PASSWORD
            objectName: db-password
```

**Security tips**
- Prefer mounted files for highest secrecy (not stored in etcd).
- If syncing to K8s Secrets, scope RBAC and avoid `env` echoing in logs.
- Rotate secrets in KV; pods will refresh on re-mount/restart (or configure rotation via CSI driver).

---

## 6) Values Reference

```yaml
# --- Identity & Meta ---
nameOverride: ""                  # overrides Release.Name in names
namespace: "apps"

serviceAccount:
  create: true
  name: "petclinic-sa"
  annotations: {}                 # add WI annotations if using AKV mode

# --- Image ---
image:
  repository: abbdemoazdevacr.azurecr.io/demo-petclinic-app/api-gateway
  tag: "latest"
  pullPolicy: IfNotPresent

imagePullSecrets: []              # e.g., [{ name: "acr-pull" }]

# --- Container ---
container:
  port: 8080
  command: []
  args: []
  env: []                         # static env pairs
  envFrom: []                     # ConfigMap/Secret refs
  livenessProbe: {}
  readinessProbe: {}
  securityContext:
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities: { drop: ["ALL"] }

resources:
  requests: { cpu: "200m", memory: "256Mi" }
  limits:   { cpu: "500m", memory: "512Mi" }

# --- Service ---
service:
  type: ClusterIP
  port: 8080

# --- Autoscaling ---
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 6
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 0   # 0 disables memory target

# --- PDB ---
pdb:
  enabled: true
  minAvailable: 1

# --- VPA (optional) ---
vpa:
  enabled: false
  updatePolicy: "Off"             # "Off" | "Initial" | "Auto"

# --- Secrets ---
secrets:
  mode: "k8s"                     # "k8s" | "akv"
  k8s:
    envFromSecretNames: []        # list of Secret names to import as env
  akv:
    vaultName: ""
    tenantId: ""
    objects: []                   # [{ name, objectName, type }]
    mountPath: "/mnt/secrets-store"
    syncKubernetesSecrets: false
    secretObjects: []             # mirror to K8s Secret(s) if needed
```

---

## 7) Upgrades, Rollbacks & Health

- Upgrade with new image tags or values:
```bash
helm upgrade --install api-gateway charts/microservice \
  -n apps -f values-api-gateway.yaml
```
- Check rollout:
```bash
kubectl -n apps rollout status deploy/api-gateway
kubectl -n apps get hpa,pdb,po,svc
```
- Rollback:
```bash
helm -n apps history api-gateway
helm -n apps rollback api-gateway <REVISION>
```

---

## 8) Troubleshooting

- **HPA not scaling**: verify Metrics Server, resources.requests set, and load present.
- **ImagePullBackOff**: check ACR permissions (AcrPull) and repo name/tag.
- **Secrets (AKV) not mounted**: confirm SA annotations, UAMI client ID, KV access, CSI driver logs.
- **CrashLoopBackOff**: check readiness/liveness probes and env configuration.

---

## 9) Next Steps (optional hardening)

- Add **NetworkPolicies** to restrict egress to only AKV endpoints and internal services.
- Use **cosign**-signed images and enforce verification via Gatekeeper/Kyverno/Ratify.
- Add **PodSecurity** standards, topology spread constraints, and resource quotas per namespace.

---

## 10) Change Log
- v1.0 — Initial README for Helm → AKS deployment with scaling & secret management.
