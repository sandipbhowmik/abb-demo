# Observability Setup using OpenTelemetry Collector


> **Scope:** This documents describes the end-to-end observability setup deployed on Azure Kubernetes Service (AKS), using an **OpenTelemetry Collector Helm chart** with **Azure Monitor exporter** authenticated via **Azure Workload Identity** to securely push traces, logs, and metrics to **Application Insights** and **Azure Monitor.**

---

## 1) High Level Architecture

- **Instrumented workloads** running on AKS emit telemetry (OTLP format, Port 4317)
- Telemetry is sent to an **OpenTelemetry Collector Deployment** inside the cluster
- Collector pipelines receive OTLP traces/logs/metrics → batch process → export to Azure
- The collector uses a **User-Assigned Managed Identity**, federated via **Workload Identity**, to authenticate securely to Azure without secrets
- Exported telemetry is ingested into:
        -  **Application Insights**(traces, dependencies, live metrics, logs)
        -  **Azure Monitor Metrics & Logs**