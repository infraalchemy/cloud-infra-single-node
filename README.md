# Moodle Infrastructure Project

### Docker • Kubernetes • Terraform • Google Cloud

This repository documents the evolution of a Moodle deployment from Docker Compose to a local Kubernetes cluster using KinD, and ultimately to Google Cloud using Terraform and GitHub Actions.

I chose Moodle because it is a stateful, multi-tier application that exercises networking, storage, ingress, initialization, and persistent data. Building the same application across multiple deployment models has provided hands-on experience with modern DevOps and cloud infrastructure practices.

## Technical Architecture

* **Application Stack:** Moodle LMS packaged with custom PHP extensions, Nginx, PHP-FPM, MySQL, and decoupled environment configurations.
* **Local Orchestration:** KinD (Kubernetes in Docker) running on Windows/WSL2 for local Kubernetes development and validation.
* **Infrastructure as Code:** Terraform modules for provisioning Google Cloud infrastructure.
* **CI/CD Automation:** Planned GitHub Actions workflows for automated container image builds and deployments.

## Repository Structure

```text
├── .github/                     # GitHub Actions workflows
├── docker/                      # Docker configurations and application settings
├── Dockerfile                   # Moodle application image build
├── kubernetes/                  # Kubernetes application manifests
│   ├── mysql/                   # MySQL database deployment
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── nginx/                   # Nginx reverse proxy deployment
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml 
│   ├── php/                     # PHP-FPM Moodle application deployment
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── storage/                 # Persistent Moodle storage
│   │   └── moodle-storage.yaml
│   └── overlays/                # Environment-specific configuration
│       ├── local-kind/          # Local KinD Kubernetes environment
│       │   ├── ingress.yaml
│       │   ├── kind-config.yaml
│       │   └── kustomization.yaml
│       └── prod-gcp/            # Planned GKE deployment
└── terraform/                   # Infrastructure as Code (IaC) for Google Cloud
    ├── modules/                 # Reusable, isolated infrastructure blocks
    │   ├── gke/                 # Google Kubernetes Engine cluster and node pool definitions
    │   └── vpc/                 # Google Cloud VPC networking, subnets, and NAT gateways
    ├── main.tf                  # Root module invoking VPC and GKE architectures
    ├── outputs.tf               # Infrastructure outputs (GKE endpoints, kubeconfig tokens)
    └── variables.tf             # Input variables (GCP Project ID, region, machine types)
```

## Project Documentation

To keep the repository clean and easy to navigate, I have broken the technical operational details down into three dedicated engineering logs:

* 📄 **[P1 Deployment Guide](./p1_deployment.md)** (Docker Compose / GCP VM): Build and deploy the containerized Moodle environment.
* 📄 **[P1 Post-Mortem](./p1_post_mortem.md)** (Docker Compose / GCP VM): Troubleshooting and lessons learned from the cloud container deployment.

* 📄 **[P2 Deployment Guide](./p2_deployment.md)** (Kubernetes / KinD): Deploy the Moodle stack into the local Kubernetes environment.
* 📄 **[P2 Post-Mortem](./p2_post_mortem.md)** (Kubernetes / KinD): Troubleshooting Kubernetes networking, ingress, storage, and scheduling issues.

* 📄 **[P3 Deployment Guide](./p3_deployment.md)** (Future GCP Automation): Planned cloud automation improvements.
* 📄 **[P3 Post-Mortem](./p3_post_mortem.md)** (Future GCP Automation): Reserved for future deployment learnings.

---

## Current Local Architecture Model

```text
                 Browser
                    │
                    ▼
        NGINX Ingress Controller
                    │
                    ▼
          Kubernetes Service
                    │
                    ▼
             PHP-FPM / Moodle
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
      MySQL             Persistent Storage
```

---

# Cloud Infrastructure Progression: My Project Journey

This project follows the evolution of the same Moodle application through increasing levels of infrastructure complexity. Rather than building isolated labs, I chose to evolve the same application through multiple deployment models, solving real infrastructure problems along the way.

## Phase 1 – Virtual Cloud Instances & Container Networking (Docker Compose to GCP VM)
### Goal
Build and run a complete Moodle stack using containerized services on cloud infrastructure.
### Architecture & Implementation
I began by containerizing the core application layers and managing them as isolated workloads (Nginx, PHP-FPM, MySQL) on a single virtual host interface. The stack was deployed on a production-grade Linux VM instance (Compute Engine) running natively on Google Cloud. 
### Results & Skills Mastered
Created a working containerized Moodle environment. Engineered private, isolated bridge networks inside Docker Compose so separate container runtimes could communicate securely on the live host instance. Mastered local volume persistence bounds, resource configurations, and cloud network security firewalls, establishing a solid foundation for migration into Kubernetes.


## Phase 2 – Local Cluster Orchestration & Debugging (Kubernetes with KinD)
### Goal
Migrate the Docker-based Moodle deployment into a local KinD Kubernetes cluster to implement and validate container orchestration, networking, ingress routing, storage, and application deployment workflows before moving to the cloud.
### Architecture & Implementation
The Docker-based Moodle deployment was migrated into Kubernetes by combining custom container images with declarative Kubernetes objects (Deployments, ClusterIP Services, Persistent Volume Claims, Secrets, ConfigMaps, initContainers, and Ingress routing rules). 
### Results & Skills Mastered
Successfully deployed Moodle as a multi-tier Kubernetes application running locally on KinD on Windows 11/WSL2. Operating locally exposed a number of Windows, Docker, and Kubernetes integration edge cases that required deep-dive troubleshooting. I diagnosed and resolved core engineering bottlenecks, including cross-container network locks, proxy timeout limits, and ingress-to-node scheduling dependencies.


## Phase 3 – Managed Cloud Clusters & Automation (The Planned Roadmap)
### Goal
Move the validated Kubernetes architecture from a local verification sandbox directly onto a highly available, completely automated public cloud framework.
### Planned Architecture & Automation
The final tier of the pipeline project will evolve the architecture into a managed Google Kubernetes Engine (GKE) cluster, provisioned entirely through modular, declarative Terraform blueprints to completely prevent cloud configuration drift. Deployments will be orchestrated via automated GitHub Actions workflows leveraging secure OIDC identity federation to authenticate against Google Cloud, building image layers and deploying manifests right from source control triggers without static security keys.
