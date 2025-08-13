# Secrets Scanning & Code Security

> **Scope:** This README documents how the CI workflow runs **secret scanning** and **code security analysis** _before_ any container build/push. It is designed for **private repos without GitHub Advanced Security (GHAS)** and uses open‑source scanners and CI gates to block risky changes.

---

## GitHub Advanced Security

GitHub Advanced Security for secret scanning and code security analysis capabilities **require purchase** of GitHub’s Advanced Security products:

- **GitHub Secret Protection** — features to help detect and prevent secret leaks, such as **secret scanning** and **push protection**.
- **GitHub Code Security** — features to help find and fix vulnerabilities, like **code scanning**, **premium Dependabot features**, and **dependency review**.
- GitHub makes **extra security features** available to customers who purchase GitHub Code Security or GitHub Secret Protection. **GitHub Code Security** and **GitHub Secret Protection** are available for accounts on **GitHub Team** and **GitHub Enterprise Cloud**.

> **Hence**, considering the above point, this CI pipeline is designed to operate **without GitHub’s Advanced Security products**. The equivalent coverage can be implemented using open‑source tools and branch protections.

---

## 1) High‑Level Architecture



**Key points**
- Triggers on `pull_request` and `push` (to default branches).
- **Self‑hosted** runner executes all scans.
- **Required status checks** gate merges (no GHAS required).

---

## 2) Pipeline Stages & Gates

1) **Checkout & environment prep**  
   Sets up Java/Maven (for Java repos) and any language‑specific tooling.

2) **Secret scanning (CI)**  
   - **Gitleaks**: scans repository (and optionally history) for secrets, fails on any finding.  
   - **TruffleHog** (optional): additional patterns for robustness.

3) **Static App Security Testing (SAST)**  
   - **Semgrep** (OSS rules for Java): fast source analysis; annotates PRs and fails on high‑severity findings.  
   - **SpotBugs** (optional, via Maven) can be added for Java bytecode analysis.

4) **Software Composition Analysis (SCA)**  
   - **OWASP Dependency‑Check**: flags vulnerable dependencies using NVD/OSS Index; **fails** if CVSS ≥ 7.0.  
   - (Optional) **OSV Scanner** for additional coverage.

5) **Dockerfile hygiene (pre‑build)**  
   - **Hadolint** to catch insecure Dockerfile practices before images are built.

6) **Repository vulnerability scan (optional)**  
   - **Trivy fs** mode scans the working tree for known CVEs in vendored binaries & SBOM content.

7) **Reporting & Gates**  
   - Save reports as **Actions artifacts** (JSON/HTML/XML).  
   - Return **non‑zero exit codes** to fail the job on HIGH/CRITICAL findings.  
   - Enforce **branch protection** so PRs cannot merge unless all required checks pass.

---

## 3) Change Log
- **v1.0** — Initial design for secret & code security scanning without GHAS.
