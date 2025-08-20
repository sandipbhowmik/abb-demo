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

Namespace creation for the deployment (if not already created):
```bash
kubectl create namespace abb-demo-spring-petclinic --dry-run=client -o yaml | kubectl apply -f -
```

---

## 2) Helm Chart Layout

- The **Umbrella Chart** structure is followed here using a single umbrella Helm chart (sometimes called a parent or aggregator chart) with sub-charts for each microservice. Its preferred in enterprises for:
  - One chart controls the deployment of the entire application stack
  - Versions of services can be locked together
  - Each microservice still has its own Helm chart, but production promotes them through the umbrella

```kotlin
abb-demo-spring-petclinic/
├── Chart.yaml
├── values.yaml                    <-- global/shared values (AKV, UAMI, registry, HPA defaults, etc.)
└── charts/
    ├── api-gateway/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── serviceaccount.yaml
    │       ├── deployment.yaml
    │       ├── hpa.yaml
    │       ├── service.yaml
    │       └── secretproviderclass.yaml
    │
    ├── config-server/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── serviceaccount.yaml
    │       ├── deployment.yaml
    │       ├── hpa.yaml
    │       ├── service.yaml
    │       └── secretproviderclass.yaml
    │
    ├── customers-service/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── serviceaccount.yaml
    │       ├── deployment.yaml
    │       ├── hpa.yaml
    │       ├── service.yaml
    │       └── secretproviderclass.yaml
    │
    ├── vets-service/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── serviceaccount.yaml
    │       ├── deployment.yaml
    │       ├── hpa.yaml
    │       ├── service.yaml
    │       └── secretproviderclass.yaml
    │
    ├── visits-service/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── serviceaccount.yaml
    │       ├── deployment.yaml
    │       ├── hpa.yaml
    │       ├── service.yaml
    │       └── secretproviderclass.yaml
    │
    └── chat-agent/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── serviceaccount.yaml
            ├── deployment.yaml
            ├── hpa.yaml
            ├── service.yaml
            └── secretproviderclass.yaml

```

---

## 3) **Azure Key Vault** via Secrets Store CSI + Workload Identity
 
1) Ensure cluster prerequisites for **Workload Identity** and **Secrets Store CSI** are installed and the UAMI has KV access.

2) Prepare a values file (e.g., `values-customers.yaml`):
```yaml
global:
  acr: abbdemoazdevacr.azurecr.io        
  imageNamespace: demo-petclinic-app     
  imageTag: latest                       
  namespace: abb-demo-spring-petclinic

  workloadIdentity:
    clientId: <UAMI_CLIENT_ID>           
    tenantId: <TENANT_ID>               
    uamiName: abb-demo-az-dev-wi

  azureKeyVault:
    name: abbdemoazdevkv
    secrets:
      username: mysql-admin-login
      password: mysql-admin-password

  mysql:
    hostname: <mysql-flexible-host>
    port: 3306
    database: petclinic

hpa:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
```

---
## 4) Scaling Configurations

### 4.1 Resource Requests & Limits
- Set `resources.requests` and `resources.limits` for CPU/Memory.
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
