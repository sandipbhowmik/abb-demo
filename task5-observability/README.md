# Observability Setup using OpenTelemetry Collector


> **Scope:** This documents describes the end-to-end observability setup deployed on Azure Kubernetes Service (AKS), using an **OpenTelemetry Collector Helm chart** with **Azure Monitor exporter** authenticated via **Azure Workload Identity** to securely push traces, logs, and metrics to **Application Insights** and **Azure Monitor.**

---

## 1) High Level Architecture

<img width="2049" height="1094" alt="image" src="https://github.com/user-attachments/assets/8600aac4-7a2d-4835-b7b7-585b58f0c1bd" />



- **Instrumented workloads** running on AKS emit telemetry (OTLP format, Port 4317)
- Telemetry is sent to an **OpenTelemetry Collector Deployment** inside the cluster
- Collector pipelines receive OTLP traces/logs/metrics → batch process → export to Azure
- The collector uses a **User-Assigned Managed Identity**, federated via **Workload Identity**, to authenticate securely to Azure without secrets
- Exported telemetry is ingested into:
        -  **Application Insights**(traces, dependencies, live metrics, logs)
        -  **Azure Monitor Metrics & Logs**

---

## 2) Components Involved

| Component                               | Purpose                                                  |
|----------------------------------------|----------------------------------------------------------|
| OpenTelemetry Collector Deployment     | Runs inside AKS, hosts OTLP receiver and Azure exporter  |
| ServiceAccount + Workload Identity     | Collector pod uses UAMI for AAD-based auth              |
| Azure Monitor Exporter                 | Sends telemetry to Application Insights + Azure Monitor  |
| Kubernetes Secret                      | Holds Instrumentation Key (referenced via Argo CD)       |
| Helm Chart (`charts/otel-collector`)   | Deploys Collector                                        |


---

## 3) Implementation Steps

### 1. 1. Enable Azure Workload Identity on AKS

- Allows Kubernetes service accounts to authenticate as Azure AD identities. This enables to have the Collector pod assume a Managed Identity, eliminating the need to store service principals or secrets.

```bash
az aks update \
  -g <RESOURCE_GROUP> -n <AKS_CLUSTER_NAME> \
  --enable-oidc-issuer \
  --enable-workload-identity
```

### 2. Create a User-Assigned Managed Identity

- UAMI will be used as reusable object across clusters/namespaces and lifecycle-aware, unlike an AKS system-assigned identity which is coupled to the cluster. It will give consistent identity for telemetry export to Azure services.

```bash
az identity create \
  --name abb-demo-az-dev-wi \
  --resource-group abb-demo-wl-rg
```

### 3. Role Assignments

- These roles allow the identity to push metrics/traces into Azure Monitor and Application Insights without using instrumentation keys for authentication.

```bash
# Telemetry to Azure Monitor
az role assignment create \
  --assignee <UAMI_CLIENT_ID> \
  --role "Monitoring Metrics Publisher" \
  --scope "/subscriptions/<SUB_ID>"

# Exporter access to Application Insights
az role assignment create \
  --assignee <UAMI_CLIENT_ID> \
  --role "Application Insights Component Contributor" \
  --scope "/subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/microsoft.insights/components/<APP_INSIGHTS_NAME>"
```

---

## 4) Federate Kubernetes service account with UAMI

- The below steps will be used to allow to request AAD access tokens on behalf of the UAMI when the collector pod runs using service account `otel-collector-sa`.

**serviceaccount.yaml**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otel-collector-sa
  namespace: observability
  annotations:
    azure.workload.identity/client-id: <UAMI_CLIENT_ID>
```

**Federated credential mapping:**

```bash
az identity federated-credential create \
  --identity-name <uami-name> \
  --resource-group <rg> \
  --name otel-collector-fic \
  --issuer <OIDC_ISSUER> \
  --subject system:serviceaccount:observability:otel-collector-sa
```

---

## 5) Install OpenTelemetry Collector via Helm

- The OpenTelemetry collector has been deployed under ArgoCD using the helm charts located at `charts/otel-collector`

```kotlin
charts/
└─ otel-collector/
    ├─ Chart.yaml
    ├─ values.yaml
    └─ templates/
        ├─ serviceaccount.yaml
        ├─ deployment.yaml
        ├─ service.yaml
        └─ configmap.yaml
docs/
└─ README.md  (this file)
```

- It Uses OpenTelemetry protocol (OTLP) receiver – cloud-native input protocol for traces, metrics, logs

- Uses the AzureMonitor exporter – single exporter that sends data to both App Insights and Azure Monitor

- Connection string uses only the ingestion endpoint and instrumentation key for target identification, not authentication (auth is done via MSI).

**Note:** Credentials materials are kept out of Git, while still allowing ArgoCD to inject them into the chart at runtime using secrets.

**Relevant values.yaml**

```yaml
workloadIdentity:
  clientId: "<UAMI_CLIENT_ID>"

exporters:
  azuremonitor:
    connection_string: "InstrumentationKey={{ .Values.azureMonitor.instrumentationKey }};IngestionEndpoint=https://centralus.ingestion.monitor.azure.com/"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [azuremonitor]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [azuremonitor]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [azuremonitor]
```

---