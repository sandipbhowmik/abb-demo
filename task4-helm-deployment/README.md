# Deploying PetClinic to AKS with Helm
This document explains how to deploy the Petclinic application to **Azure Kubernetes Service (AKS)** using a **Helm chart** that includes:
- **Scaling**: resources, Horizontal Pod Autoscaler (HPA), PodDisruptionBudget (PDB).
- **Secret management**: **Azure Key Vault** via **Secrets Store CSI Driver** + **Azure Workload Identity**.

> Each service (e.g., `api-gateway`, `customers-service`) as a separate Helm with its own values file. The helm charts are deployed here - `charts/abb-demo-spring-petclinic`

---

## 1) Prerequisites

- An AKS cluster with:
  - Access configured on your machine: `az aks get-credentials -g <put resource group name> -n <aks cluster name>`
  - **Metrics Server** installed (required for HPA).
  - **AcrPull** permission from AKS to your ACR (image pulls).
- Using **Azure Key Vault** mode with:
  - **OIDC/Workload Identity** enabled on AKS.
  - **Secrets Store CSI Driver** and **Azure Key Vault provider** installed cluster-wide.
  - A **User-Assigned Managed Identity (UAMI)** with **Key Vault Secrets User** on the target vault.
  - A Federated Identity Credential that binds `system:serviceaccount:apps:petclinic-sa` to the UAMI.
- Helm 3.12+ and kubectl 1.27+ on your workstation.

Namespace creation for the deployment:
```bash
kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -
```

---

## 2) Standard Chart Layout
```
charts/microservice/
  Chart.yaml
  values.yaml                  # defaults
  templates/
    deployment.yaml
    service.yaml
    hpa.yaml
    pdb.yaml
    serviceaccount.yaml
    csi-secretproviderclass.yaml  # used when secrets.mode = "akv"
```

---

## 3) **Azure Key Vault** via Secrets Store CSI + Workload Identity
 
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

---

## 5) Azure Key Vault via CSI + Workload Identity

- No long-lived credentials inside cluster; pods authenticate via **Workload Identity** using SA → OIDC → UAMI.
- Two consumption options:
  1) **Mounted files** under `mountPath` (ephemeral, not persisted to etcd). Prefer mounted files for highest secrecy as it not stored in etcd.
  2) **Sync to Kubernetes Secret** (`syncKubernetesSecrets: true`) to use `envFrom` or `secretKeyRef`. If syncing to K8s Secrets, scope RBAC and avoid `env` echoing in logs.
     
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

## 10) Change Log
- v1.0 — Initial README for Helm → AKS deployment with scaling & secret management.
