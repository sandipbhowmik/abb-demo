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

- Autoscaling enabled using `HorizontalPodAutoscaler` (apiVersion `autoscaling/v2`)
- Global HPA configuration:
  - `minReplicas: 2`
  - `maxReplicas: 5`
  - `targetCPUUtilizationPercentage: 70`
- ArgoCD/Helm renders a per-microservice HPA using the global values.
> Pods scale up/down automatically based on CPU utilization metrics.


---


## 5) Deployment of Application in AKS using GitOps with ArgoCD

- All Helm charts are stored in Git under `charts/abb-demo-spring-petclinic`
- An ArgoCD Application points to this path and automatically:
  - Watches Git (`main/master`)
  - Syncs changes to the AKS cluster
  - Ensures state reconciliation, rollbacks and self-heal.


---


## 10) Change Log
- v1.0 — Initial README for Helm → AKS deployment with scaling & secret management.
