# Enterprise Moodle Deployment Pipeline (Docker, Kubernetes & Terraform)

A production-grade DevOps repository demonstrating the containerization, orchestration, and infrastructure provisioning of an enterprise Moodle Learning Management System (LMS). This project implements industry-standard practices to eliminate configuration drift, automate staging deployments, and manage complex application dependencies.

## 🏗️ Technical Architecture

*   **Application Core:** Moodle LMS packaged with custom PHP extensions, Nginx, and decoupled environment configurations.
*   **Local Orchestration:** KinD (Kubernetes in Docker) on Windows/WSL2 for local cluster testing and verification.
*   **Infrastructure as Code:** Terraform modules for provisioning scalable cloud environments (GCP/Azure).
*   **CI/CD Automation:** GitHub Actions workflows managing automated container image builds and deployment triggers.

---

## 📂 Repository Structure

```text
├── .github/             # GitHub Actions workflows for CI/CD automation
├── docker/              # Nginx server blocks, PHP-FPM tuning, and environment configs
├── kubernetes/          # K8s manifests (Deployments, StatefulSets, Ingress, and KinD configs)
├── terraform/           # IaC modules for cloud compute, networking, and storage components
├── Dockerfile           # Multi-stage blueprint compiling Moodle core and PHP dependencies
└── README.md            # Architecture overview and deployment guide
```

---

## 🛠️ Engineering Challenges & Solutions

Moodle traditionally relies on tightly coupled PHP extensions, local caching, and stateful file storage. This project addresses those enterprise constraints by implementing:

### 1. Optimized Dependency Layering
Utilizes multi-stage Docker builds to compile essential PHP extensions (e.g., `gd`, `intl`, `mysqli`, `opcache`) while minimizing final image size and reducing the security attack surface.

### 2. Decoupled & Stateless Architecture
Separates the web tier from the database layer and manages the stateful `moodledata` directory using Kubernetes Persistent Volumes (PVs) and Claims (PVCs) to ensure high availability and horizontal scalability.
