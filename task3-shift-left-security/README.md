# Secrets Scanning & Code Security

> **Scope:** This documents describes the **secret scanning** and **code security analysis** implemented in the CI/Build action workflow. It is designed with the usage of **GitHub Advanced Security (GHAS)** which uses scanners and gates to block risky changes.

---

## GitHub Advanced Security

GitHub Advanced Security for secret scanning and code security analysis capabilities:

- **GitHub Secret Protection** — features to help detect and prevent secret leaks, such as **secret scanning** and **push protection**.
- **GitHub Code Security** — features to help find and fix vulnerabilities, like **code scanning**, **premium Dependabot features**, and **dependency review**.
- GitHub makes **extra security features** available to customers who purchase GitHub Code Security or GitHub Secret Protection.

> **Please note, **GitHub’s Advanced Security products i.e secret scanning and code security analysis for private repo can't be enabled until license is purchased. However, the equivalent coverage can be implemented using open‑source tools and branch protections for private repos.**

---

## 1) High‑Level Architecture

![HLD Shift Left Security](shift-left-security.png "CI/CD Security ")

**Key points**
- Triggers on `pull_request`(this is must for prod deployment; not demonstrated in this build and push pipeline),`push`.
- **Self‑hosted** runner executes all scans.

---

## 2) Pipeline Stages & Gates

1) **Checkout & environment prep**  
   Sets up Java/Maven (for Java repos) and any language‑specific tooling.

2) **Secret scanning (CI)**  
   - **Gitleaks**: scans repository (and optionally history) for secrets, fails on any finding.  

3) **Static App Security Testing (SAST)**  
   - **Semgrep** (OSS rules for Java): fast source analysis; annotates PRs and fails on high‑severity findings.

4) **Software Composition Analysis (SCA)**  
   - **OWASP Dependency‑Check**: flags vulnerable dependencies using NVD/OSS Index; **fails** if CVSS ≥ 7.0.

5) **Dockerfile hygiene (pre‑build)**  
   - **Hadolint** to catch insecure Dockerfile practices before images are built.

7) **Reporting & Gates**  
   - Save reports as **Actions artifacts** (JSON/HTML/XML).  
   - Return **non‑zero exit codes** to fail the job on HIGH/CRITICAL findings.  
   - Enforce **branch protection** so PRs cannot merge unless all required checks pass.

---

## 3) Change Log
- **v1.0** — Initial design for secret & code security scanning without GHAS.
