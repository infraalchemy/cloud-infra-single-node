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
├── .github/                     # GitHub Actions CI/CD workflows for automated builds
├── docker/                      # Nginx configurations, PHP parameters, and Moodle env variables
├── Dockerfile                   # Multi-stage blueprint compiling Moodle core and PHP dependencies
├── kubernetes/                  # Kubernetes manifests for application deployment
│   ├── base/                    # Core application manifests shared across all environments
│   │   ├── jobs/                # Moodle cron engine and database migration tasks
│   │   ├── mysql/               # MySQL StatefulSet and database configurations
│   │   ├── nginx/               # Nginx reverse proxy deployment and server blocks
│   │   ├── php/                 # PHP-FPM deployment and application configurations
│   │   └── storage/             # Persistent Volume Claims for moodledata
│   └── overlays/                # Environment-specific overrides (Kustomize)
│       ├── local-kind/          # Local cluster tweaks (NodePorts, local storage classes)
│       └── prod-gcp/            # GCP GKE configurations (Cloud Load Balancer, persistent cloud disks)
└── terraform/                   # Infrastructure as Code (IaC) for Google Cloud
    ├── modules/                 # Reusable, isolated infrastructure blocks
    │   ├── gke/                 # Google Kubernetes Engine cluster and node pool definitions
    │   └── vpc/                 # Google Cloud VPC networking, subnets, and NAT gateways
    ├── main.tf                  # Root module invoking VPC and GKE architectures
    ├── outputs.tf               # Infrastructure outputs (GKE endpoints, kubeconfig tokens)
    └── variables.tf             # Input variables (GCP Project ID, region, machine types)
```

---

## 🛠️ Engineering Challenges & Solutions

Moodle traditionally relies on tightly coupled PHP extensions, local caching, and stateful file storage. This project addresses those enterprise constraints by implementing:

### 1. Optimized Dependency Layering
Utilizes multi-stage Docker builds to compile essential PHP extensions (e.g., `gd`, `intl`, `mysqli`, `opcache`) while minimizing final image size and reducing the security attack surface.

### 2. Decoupled & Stateless Architecture
Separates the web tier from the database layer and manages the stateful `moodledata` directory using Kubernetes Persistent Volumes (PVs) and Claims (PVCs) to ensure high availability and horizontal scalability.

---

## 💻 Local Orchestration (KinD)

For localized developer verification on Windows/WSL2, the environment simulates a multi-node cluster locally before code hits the cloud.

### 1. Spin up the local cluster
```bash
kind create cluster --config kubernetes/overlays/local-kind/kind-config.yaml
```

### 2. Deploy Local Workloads
Apply the manifests using native Kubernetes Kustomize to inject local storage rules and development network ports:
```bash
kubectl apply -k kubernetes/overlays/local-kind/
```

---

## 🚀 Cloud Deployment (Google Cloud Platform)

For enterprise-scale production, this repository transitions from local orchestration to a highly available, secure **Google Kubernetes Engine (GKE)** cluster provisioned entirely through Infrastructure as Code (IaC).

### 1. Provision Infrastructure via Terraform
Initialize the cloud provider backend and execute the plan to build the isolated VPC network, firewall boundaries, and the managed GKE cluster:
```bash
cd terraform/
terraform init
terraform apply -auto-approve
```

### 2. Authenticate the Cloud Cluster
Securely link your local `kubectl` context to the newly minted Google Cloud GKE control plane:
```bash
gcloud container clusters get-credentials moodle-gke-cluster \
    --region us-central1 \
    --project your-gcp-project-id
```

### 3. Environment-Targeted Deployment
Deploy the core workloads while dynamically swapping local shortcuts for production gear (such as Google Cloud Persistent Disks and an enterprise HTTP(S) Load Balancer):
```bash
kubectl apply -k kubernetes/overlays/prod-gcp/
```

