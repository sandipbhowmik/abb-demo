# GitOps with Argo CD on AKS — Helm-Based Deployments

This README explains how **Argo CD** automates deployments of your **Helm chart** to **Azure Kubernetes Service (AKS)**, how it **tracks versions**, and how to **roll back** reliably. It includes installation, GitHub PAT integration, and app configuration.

> Conventions used below:
> - **AKS namespace for Argo CD:** `argocd`
> - **Workloads namespace:** `apps`
> - **Repo path for the chart:** `charts/microservice` (adjust as needed)
> - **Registry:** `abbdemoazdevacr.azurecr.io` (AKS nodes need **AcrPull**)
> - **Secrets mode:** `k8s` or `akv` (Azure Key Vault via CSI + Workload Identity)
> - **ServiceAccount for apps:** `petclinic-sa`

---

## 1) What Argo CD Automates

- **Continuous deployment (CD)**: watches your Git repository for changes to the **Helm chart** and **values**; on change, **renders** and **syncs** to the cluster.
- **Versioned deployments**: every deployed state maps to a **Git commit/Helm revision** (visible in Argo CD UI & history).
- **Self-healing**: if runtime drift occurs (manual change), Argo CD restores the **desired state** from Git.
- **Pruning**: removes objects that no longer exist in Git (prevents config drift/orphans).
- **Rollback**: revert to any prior **Git commit** or **Application history** entry with one command or click.

---

## 2) Prerequisites

- kubectl access to your AKS cluster.
- Helm 3.x installed locally.
- (Private repos) a **GitHub Personal Access Token (PAT)** with **read-only** access to the repo (`repo:read`).
- If your chart references Azure Key Vault via CSI + Workload Identity, ensure those components are installed and configured in AKS.

---

## 3) Install Argo CD on AKS

Create the Argo CD namespace and install the official manifests:
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Get the initial **admin** password (auto-generated secret):
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

Expose the Argo CD API/UI (choose one):
- **Port-forward (quickstart):**
  ```bash
  kubectl -n argocd port-forward svc/argocd-server 8080:443
  # UI: https://localhost:8080  |  user: admin  |  pass: <from secret above>
  ```
- **Ingress (recommended for teams):** create an Ingress for `argocd-server` with TLS and SSO as desired.

Install the Argo CD CLI (optional but recommended):
```bash
# macOS
brew install argocd
# Login (if using port-forward)
argocd login localhost:8080 --username admin --password <PASSWORD> --insecure
```

---

## 4) Connect Argo CD to Your GitHub Repo (PAT)

### Option A — CLI
```bash
argocd repo add https://github.com/<org>/<repo>.git \
  --username <github-username> \
  --password <github-pat> \
  --name petclinic-repo
```

### Option B — Kubernetes Secret (Repository Credentials)
Create a Secret in `argocd` namespace so Argo CD can read your repo:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: repo-github-pat
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: https://github.com/<org>/<repo>.git
  username: <github-username>
  password: <github-pat>   # read-only PAT recommended
```
```bash
kubectl apply -f repo-github-pat.yaml
```

> **Security tip:** scope the PAT to **read-only** repository access; prefer **deploy keys** or **GitHub App** credentials when possible.

---

## 5) Configure the Argo CD Application (Helm)

Minimal **Application** manifest targeting your Helm chart in Git:
```yaml
# app-petclinic.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: petclinic
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<org>/<repo>.git
    targetRevision: main              # can be a branch, tag, or commit SHA
    path: charts/microservice         # path to your chart in the repo
    helm:
      releaseName: api-gateway        # or customers-service, etc. (one app per service)
      valueFiles:
        - environments/dev/api-gateway.values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: apps
  syncPolicy:
    automated:
      prune: true                     # remove obsolete resources
      selfHeal: true                  # correct drift automatically
    syncOptions:
      - CreateNamespace=true
  revisionHistoryLimit: 10
```
Apply it:
```bash
kubectl apply -f app-petclinic.yaml
```

Create more `Application` objects for each microservice (or use the **App-of-Apps** pattern for multi-env).

---

## 6) How Versioned Deployments Work

Argo CD ties cluster state to a **Git revision**:
- `spec.source.targetRevision` can be:
  - A **branch** (e.g., `main`) → always deploy the latest commit on that branch.
  - A **tag** (e.g., `v1.2.3`) → deploy that **fixed version**.
  - A **commit SHA** → deploy an exact commit.
- With **Helm**, your **values files** (or chart version if using an external chart repo) encode the **image tag** and settings.
- For **environment promotion**, use Git branches or folders (`dev`, `stage`, `prod`) and promote via **pull request** (Git becomes the change control).

**Example values (snippet)** pinning an image tag:
```yaml
image:
  repository: abbdemoazdevacr.azurecr.io/demo-petclinic-app/api-gateway
  tag: "sha-<commit-sha>"   # or "1.0.7"
```

> Optional: use **Argo CD Image Updater** to track new tags automatically (policy-driven) and commit updated values back to Git.

---

## 7) Automatic Sync from GitHub Changes

Two ways Argo CD discovers changes:
1. **Webhook (fast):** configure a webhook in your GitHub repo →
   - URL: `https://<argocd-host>/api/webhook`
   - Content type: `application/json`
   - Secret: set a shared secret in both GitHub and Argo CD
2. **Polling (default):** Argo CD periodically polls repos and detects new commits (slower but no webhook needed).

With **Automated Sync** enabled, Argo CD applies the new manifests as soon as the change is detected.

---

## 8) Rollouts and Health

- Argo CD waits for **health**: Deployments become **Healthy** when pods pass readiness/liveness probes.
- Use **HPA/PDB** (from your Helm chart) to maintain SLOs during rolling updates.
- Configure **Sync Waves** and **hooks** in Helm (pre/post sync) for ordered changes (DB migrations, etc.).

---

## 9) Rollback Strategies

### A) Git Revert (recommended)
- Revert/rollback the problematic commit in Git (values/chart).
- Argo CD detects the new desired state and reconciles the cluster.

### B) Argo CD History (instant rollback)
```bash
argocd app history petclinic
# pick a revision ID
argocd app rollback petclinic <ID>
```
- The cluster returns to the previously recorded **deployed revision**. Consider committing a corresponding Git revert to keep Git and cluster aligned.

### C) Pin to a known-good tag
- Change `targetRevision` from `main` to a **stable tag** (e.g., `v1.2.3`) temporarily.

---

## 10) Multi-Environment (Optional App-of-Apps)

Parent Application defining environment child apps:
```yaml
# app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: petclinic-environments
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<org>/<repo>.git
    targetRevision: main
    path: environments           # folder with child Application yamls
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated: { prune: true, selfHeal: true }
```
Each child (dev/stage/prod) points to the same chart, different `values.yaml` and possibly `targetRevision` tags.

---

## 11) Access & RBAC

- Argo CD’s **Application Controller** should have **least privilege** to only the target namespaces (e.g., `apps`).
- Use Projects (`AppProject`) to restrict repo URLs, destinations, and cluster-scoped resources.
- Prefer SSO/OIDC for the Argo CD UI and use **RBAC** roles to manage who can sync/override/rollback.

---

## 12) Operational Tips

- **Drift detection:** Out-of-band `kubectl` changes will show **OutOfSync**; with self-heal ON, Argo CD will revert them.
- **Pruning:** Keep Git authoritative; remove resources from Git to have Argo CD **delete** them safely.
- **Secrets:** Store **references** (e.g., AKV SecretProviderClass) in Git, not secret material.
- **Observability:** Enable OpenTelemetry/metrics in the chart and surface Argo CD app status to your dashboards.
- **Backups:** Backup the Argo CD namespace (esp. `Application` CRs) and maintain IaC for Argo CD itself.

---

## 13) Troubleshooting

- **Repo access errors**: recheck PAT permissions or deploy key; `argocd repo list`.
- **Sync failures**: view app events/logs; `argocd app get <app>`; `kubectl describe` failed objects.
- **Health timeouts**: verify probes/HPA; ensure image exists in ACR and nodes can pull (AcrPull).
- **Webhook not triggering**: confirm URL/secret and that Argo CD server is reachable externally; fall back to polling.

---

## 14) Quick Command Summary

```bash
# Install
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
kubectl -n argocd port-forward svc/argocd-server 8080:443
argocd login localhost:8080 --username admin --password <PASSWORD> --insecure

# Connect repo (PAT)
argocd repo add https://github.com/<org>/<repo>.git --username <user> --password <pat>

# Create app
kubectl apply -f app-petclinic.yaml

# Force a sync (if auto-sync disabled)
argocd app sync petclinic

# Rollback
argocd app history petclinic
argocd app rollback petclinic <ID>
```

---

## 15) Change Log
- **v1.0** — Initial Argo CD GitOps README for AKS with Helm, versioning, and rollback.