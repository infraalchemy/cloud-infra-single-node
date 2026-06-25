# Enterprise Moodle Deployment Pipeline (Docker, Kubernetes & Terraform)

A comprehensive DevOps repository demonstrating the containerization, local orchestration, and cloud infrastructure provisioning of an enterprise Moodle Learning Management System (LMS). This project reflects production-grade strategies used to eliminate configuration drift, automate staging deployments, and handle complex application dependencies.

## 🏗️ Technical Architecture
*   **Application Core:** Moodle LMS packaged with custom PHP extensions, Nginx, and environmental configurations.
*   **Local Runtime & Testing:** KinD (Kubernetes in Docker) on Windows/WSL2 for localized cluster verification.
*   **Infrastructure as Code:** Terraform for provisioning stable cloud environments (GCP/Azure).
*   **CI/CD Automation:** GitHub Actions (`.github/workflows`) managing image builds and deployment triggers.

---

## 📂 Repository Structure

```text
├── .github/             # GitHub Actions CI/CD workflows for automated builds
├── docker/              # Nginx configurations, PHP parameters, and Moodle environment variables
├── kubernetes/          # K8s manifests (Moodle Deployments, MySQL/Postgres Pods, KinD local config)
├── terraform/           # IaC modules to provision cloud infrastructure (GCP/Azure Compute/Storage)
├── Dockerfile           # Root blueprint compiling Moodle core and required PHP dependencies
└── README.md            # Project overview and deployment guide
```

---

## 🛠️ The Challenge: Containerizing Moodle
Moodle relies heavily on tightly coupled PHP extensions, local caching, and persistent file structures. This repository solves those challenges by:
1.  **Dependency Layering:** The root `Dockerfile` compiles necessary Linux packages and PHP extensions (e.g., `gd`, `intl`, `mysqli`, `opcache`, `zip`) efficiently using multi-stage builds.
2.  **Decoupled Architecture:** Separates the web tier from the database tier and handles the stateful `moodledata` directory using Kubernetes Persistent Volumes (PVs) and Claims (PVCs).
