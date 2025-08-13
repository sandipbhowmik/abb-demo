# Secrets Scanning & Code Security

> **Scope:** This README documents how the **secret scanning** and **code security analysis** implemented in the CI/Build action workflow. It is designed for **private repos without GitHub Advanced Security (GHAS)** and uses open‑source scanners and gates to block risky changes.

---

## GitHub Advanced Security

GitHub Advanced Security for secret scanning and code security analysis capabilities **require purchase** of GitHub’s Advanced Security products:

- **GitHub Secret Protection** — features to help detect and prevent secret leaks, such as **secret scanning** and **push protection**.
- **GitHub Code Security** — features to help find and fix vulnerabilities, like **code scanning**, **premium Dependabot features**, and **dependency review**.
- GitHub makes **extra security features** available to customers who purchase GitHub Code Security or GitHub Secret Protection. **GitHub Code Security** and **GitHub Secret Protection** are available for accounts on **GitHub Team** and **GitHub Enterprise Cloud**.

> **Hence**, considering the above point, this CI pipeline is designed to operate **without GitHub’s Advanced Security products**. The equivalent coverage can be implemented using open‑source tools and branch protections.

---

## 1) High‑Level Architecture

![HLD Shift Left Security](shift-left-security.png "CI/CD Security ")

**Key points**
- Triggers on `pull_request`,`push`.
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
