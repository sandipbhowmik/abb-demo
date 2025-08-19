# Pet Clinic Microservices on AKS with GitOps & DevSecOps

A cloud-native reference implementation of the **Spring Pet Clinic microservices application** deployed to **Azure Kubernetes Service**, demonstrating a complete **DevSecOps workflow** powered by modern tooling such as **Terraform, GitHub Actions, Argo CD, CodeQL, and OpenTelemetry**.

**Note:** The project is built based on the reference project outlined here `https://github.com/Azure-Samples/java-on-aca`.

---

## Key Features

- **Microservices Architecture** based on Java Spring Boot services (API Gateway, Config Server, Customers, Vets, Visits).
- **Infrastructure as Code** using Terraform to provision AKS, Azure Container Registry (ACR), Key Vault, Log Analytics, Application Insights, and supporting resources.
- **CI/CD Pipelines** built with **GitHub Actions**, supporting:
  - Container image build & push to ACR.
  - Automated testing, security scanning, and quality gates.
- **DevSecOps Shift-Left** practices using:
  - **CodeQL** for static code security analysis.
  - **GitHub secret scanning** to detect exposed credentials.
- **GitOps Deployment** with **Argo CD** for AKS:
  - Automatic sync of Helm-based releases directly from Git.
  - Versioned, declarative, and auditable Kubernetes deployments.
- **Observability & Monitoring**:
  - **OpenTelemetry Collector** Helm chart exporting traces/metrics.
  - Visualization in **Azure Monitor** & **Application Insights**.

---

## Technology Stack

| Layer               | Tools Used                                                    |
|--------------------|---------------------------------------------------------------|
| Cloud Platform      | Azure (AKS, ACR, VENT,  MYSQL Flexible Server, Key Vault, Log Analytics, App Insights)       |
| IaC                 | Terraform                                                     |
| CI/CD               | GitHub Actions                                                |
| GitOps              | Argo CD                                                       |
| Security Scanning   | Gitleaks, CodeQL (GitHub Advanced Security) |
| Monitoring          | OpenTelemetry, Azure Monitor, App Insights                    |
| App Framework       | Java Spring Boot Microservices                                |