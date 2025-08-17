# Build Pipeline — Github Actions Workflow Design

> **Scope:** This document describes the GitHub Actions workflow `abb-demoapp-build-and-push.yaml` that builds, tests, and pushes container images for the PetClinic microservices to **Azure Container Registry (ACR)**. It covers triggers, jobs, matrix strategy, OIDC authentication to Azure, image tagging, and **security controls** including **secret scanning** and **security scanning** using GitHub Advanced Security features.

> **Note:** **This workflow considered as CI or Continuous Integration. Continuous Deployment flow should be seperated from CI pipeline.**. 

---

## 1) Github Actions High Level Flow

![Solution architecture](github-actions-workflow-diagram.png "Github Actions High Level Flow")

**Key properties**
- **Runner:** `self-hosted` (requires Docker + Buildx, QEMU, Java 17, Maven, Azure CLI).
- **Auth:** OIDC with `azure/login@v2` (`permissions: id-token: write`), **no long-lived secrets**.
- **Registry:** `abbdemoazdevacr.azurecr.io` (ACR name: `abbdemoazdevacr`).  
- **Platforms:** `linux/amd64, linux/arm64` (via Buildx + QEMU).  
- **Tags:** `<reg>/<ns>/<svc>:sha-<github.sha>` and `:latest`.
- **Workflow Name** `abb-demo/.github/workflows
/abb-demoapp-build-and-push.yaml`

This pipeline is triggered on pushes to main/master, version tags (e.g., v*), or manual dispatch and runs on a self-hosted GitHub Actions runner that prepares Java 17, Maven, QEMU, Docker Buildx, and Dockerize v0.6.1. It fans out a matrix build for the PetClinic microservices (config-server, api-gateway, customers-service, vets-service, visits-service, chat-agent), compiles each with Maven to target/app.jar, and uses a single src/docker/Dockerfile (with module-specific build args such as EXPOSED_PORT) to build multi-architecture images (linux/amd64, linux/arm64) via Buildx. 

Authentication to Azure uses short-lived OIDC tokens (id-token: write; contents: read) with azure/login@v2, followed by az acr login to push to abbdemoazdevacr.azurecr.io, tagging every image with both sha-<GITHUB_SHA> and latest for traceability. To ensure quality and security, the pipeline runs pre-build gates: Gitleaks fail the job on any secret findings; CodeQL fails on high/critical code issues. In production these jobs required status checks under branch protection so merges are blocked on failures. The combination of OIDC-based auth (no long-lived secrets), multi-arch reproducible builds, deterministic tagging, scanning gates delivers secure, portable, and auditable releases ready for AKS consumption.

> **Note:** **This workflow considering as CI or Continuous Integration. Continuous Deployment flow should be seperated from CI pipeline.**. 

---

## 2) Triggers, Permissions

### Triggers
- `push` to `main` or `master`
-  includes a **paths** filter on the workflow file
- `tags: v*`
- `workflow_dispatch` (manual)

### Permissions
- `contents: read`  
- `id-token: write` (required for **OIDC** to Azure)

### Widen trigger paths
Here trigger path has been defined as the Github actions workflow abb-demoapp-build-and-push.yaml. However, this path can be widen below with the below changes, include `src/**`, `pom.xml`, etc. as and if required.
```yaml
on:
  push:
    branches: [ main, master ]
    paths:
      - ".github/workflows/abb-demoapp-build-and-push.yaml"
      - "src/**"
      - "pom.xml"
```

---

## 3) Job & Matrix

- **runs-on:** `self-hosted` runner
- **Matrix services:** (based on the workflow)
  Matrix jobs run in parallel, which speeds up the process compared to running each configuration sequentially
  
  - `config-server` → `spring-petclinic-config-server` (port **8888**)
  - `api-gateway` → `spring-petclinic-api-gateway` (port **8080**)
  - `customers-service` → `spring-petclinic-customers-service` (port e.g., **8081**)
  - `vets-service` → `spring-petclinic-vets-service` (port e.g., **8082**)
  - `visits-service` → `spring-petclinic-visits-service` (port e.g., **8083**)
  - `chat-agent` → `spring-petclinic-chat-agent` (port varies)
- **Build context:** `src/${{ matrix.module }}/target`
- **Dockerfile:** `src/docker/Dockerfile`
- **Environment defaults (used in this workflow):**
  - `JAVA_VERSION=17`
  - `MVN_ARGS='-B -ntp -DskipTests'`
  - `ACR_LOGIN_SERVER=abbdemoazdevacr.azurecr.io`
  - `ACR_NAME=abbdemoazdevacr`
  - `IMAGE_NAMESPACE=demo-petclinic-app`
  - `PLATFORMS=linux/amd64,linux/arm64`
  - `DOCKERIZE_VERSION=v0.6.1`

> **Tagging:**  
> `${ACR_LOGIN_SERVER}/${IMAGE_NAMESPACE}/${SERVICE}:sha-${GITHUB_SHA}` and `:latest`

---

## 4) Authentication to Azure & ACR

### OpenID Connect (Entra ID federated credentials)
- The workflow requests an **OpenID Connect (OIDC) token** from GitHub and exchanges it with **Entra ID** via `azure/login@v2` to get an Azure access token.
- The Azure App (client) must be granted **AcrPush** on the target ACR **scope** (registry-level scope only).

**Minimal roles**
- **AcrPush** on `abbdemoazdevacr` (required to push images).
- (Optional) **Reader** on the ACR resource group for discovery.

**ACR login**
- `az acr login --name $ACR_NAME` converts the Azure token into a Docker credential for `docker/build-push-action`.

**Security benefits**
- **No static secrets** in repo/actions.
- **Short‑lived tokens**, automatically rotated per run.
- **Least privilege** via scoped role assignment.

---

## 5) Build & Test

### Java build
- Maven builds each module (matrix). The Dockerfile expects `target/app.jar` and uses build args:
  - `ARTIFACT_NAME=app`
  - `EXPOSED_PORT=${{ matrix.port }}`
  - `DOCKERIZE_VERSION=${{ env.DOCKERIZE_VERSION }}`

### Tests
- Uses `-DskipTests` and fail fast on test failures:
```yaml
- name: Run unit tests
  run: mvn -B -ntp -DskipITs test
```

- Optionally added **integration tests** to run before building images:
```yaml
- name: Run integration tests
  run: mvn -B -ntp -DskipUnitTests verify -Pintegration-tests
```

---

## 6) Container Build & Push (Multi-Arch)

- `docker/setup-qemu-action@v3` + `docker/setup-buildx-action@v3` enable **multi-architecture** builds.
- `docker/build-push-action@v6` builds for `${PLATFORMS}` and **pushes a manifest list** to ACR with tags `sha-<commit>` and `latest`.

---

## 7) Security & Compliance

This section describes the **checks are in place** and **how they ensure security**, split into: **secret scanning**, **code/dependency scanning** using **Github Adavanced Security**.

### 7.1 Secret Management & Secret Scanning

**In place**
- **OIDC to Azure** → eliminates PATs/registry passwords in CI.
- **No hard-coded secrets** in the pipeline.

1. **GitHub Secret Scanning & Push Protection** (repo settings)  
   - Detects committed credentials (tokens, keys) and **blocks pushes** with known token formats.
2. **Gitleaks** (action) — blocks generic secrets patterns:
```yaml
- name: Secret scan (gitleaks)
  uses: gitleaks/gitleaks-action@v2
  with:
    args: "--no-banner --redact --verbose --exit-code 1"
```

**Why this helps**
- Catches **accidental secret leaks** early; **fails the build** so compromised keys don’t ship.
- Push Protection prevents leaks from ever landing on default branches. (**not enabled for now, however added in the design**)

### 7.2 Code & Dependency Security

1. **CodeQL** (Java): Find code-level vulnerabilities (SAST).  
```yaml
- name: Initialize CodeQL
  uses: github/codeql-action/init@v3
  with:
    languages: java
- name: Perform CodeQL Analysis
  uses: github/codeql-action/analyze@v3
```

**Gating**
- Configuration **required status checks** on `main` where if the SAST secuirty checks mentioned in the first job are not passed, build job will not trigger.

### 7.3 OSS Container Image Security (Tested as optional workflows, but not included in the petclinic demo CI workflow)

1. **Dockerfile lint** (Hadolint) — catches insecure base images and practices:
```yaml
- name: Lint Dockerfile (hadolint)
  uses: hadolint/hadolint-action@v3.1.0
  with:
    dockerfile: src/docker/Dockerfile
```
2. **Image vulnerability scan** (Trivy) — blocks known CVEs:
```yaml
- name: Trivy scan
  run: |
    trivy image \
      --scanners vuln \
      --pkg-types os,library \
      --severity HIGH,CRITICAL \
      --exit-code 1 \
      --input "${{ runner.temp }}/${{ matrix.name }}-${{ github.sha }}.tar"
```

**Why this helps**
- Prevents shipping images with **HIGH/CRITICAL CVEs**.

### 7.4 Signing

**Recommendation**
- **Cosign keyless signing** using GitHub OIDC; store signatures alongside images in ACR.
```yaml
- name: Install Cosign
  uses: sigstore/cosign-installer@v3.6.0

- name: Sign image (keyless)
  env:
    COSIGN_EXPERIMENTAL: "true"
  run: |
    cosign sign --yes ${{ steps.img.outputs.reg }}/${{ steps.img.outputs.ns }}/${{ matrix.name }}:sha-${{ github.sha }}
```

**Why this helps**
- Consumers can verify images were produced by the actual **CI** pipeline and **untampered**.

---

## 8) Quality Gates & Branch Protections

- **Required status checks**: CodeQL, Gitleaks, Unit tests.
- **Branch protection**: require PRs, code reviewer approvals, and **branch protection**. (**Must for Prod deployment, however not demonstrated in this CI workflow action**)
- **Environment protections**: require approvals for “prod” deploys with CR. (**Must for Prod deployment, however not demonstrated in this CI workflow action**)
- **Fail-fast policy**: make security steps fail the job on HIGH/CRITICAL findings.

---

## 9) Runner Requirements

Ensure the self-hosted runner has:
- Docker 24+ with Buildx; QEMU emulation
- Java 17; Maven
- Azure CLI
- Network egress to `*.azurecr.io` and GitHub endpoints
- Sufficient disk for multi-arch layer caching

---

## 10) Change Log
- **v1.0** — Initial pipeline design doc with security scanning & secret scanning.
