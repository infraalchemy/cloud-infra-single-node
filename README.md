# Moodle Infrastructure Project

### Docker • Kubernetes • Terraform • Google Cloud

This repository documents the evolution of a Moodle deployment from Docker Compose running on Google Cloud Compute Engine to a local Kubernetes cluster using KinD. Additional exploration covers Terraform infrastructure provisioning and GitHub Actions authentication with Google Cloud as future automation capabilities.

I chose Moodle because it is a stateful, multi-tier application that exercises networking, storage, ingress, initialization, and persistent data. Building the same application across multiple deployment models has provided hands-on experience with modern DevOps and cloud infrastructure practices.

## Technical Architecture

* **Cloud Deployment:** Docker Compose deployment running on Google Compute Engine.
* **Local Orchestration:** KinD (Kubernetes in Docker) running on Windows/WSL2 for local Kubernetes development and validation.
* **Infrastructure as Code:** Terraform used for Google Cloud infrastructure provisioning.
* **Cloud Automation:** GitHub Actions OIDC authentication with Google Cloud explored as a foundation for future CI/CD automation.

## Repository Structure

```text
├── .github/                     # GitHub Actions workflows
├── docker/                              # Docker Compose deployment
│   ├── docker-compose.yml               # Moodle multi-container application stack
│   │
│   ├── moodledata/                      # Persistent Moodle application data
│   │
│   ├── mysql/                           # MySQL database configuration
│   │   └── mysql-data/                  # Persistent MySQL database storage
│   │
│   ├── nginx/                           # Nginx reverse proxy container
│   │   ├── Dockerfile                   # Custom Nginx image definition
│   │   └── nginx.conf                   # Nginx web server configuration
│   │
│   └── php/                             # PHP-FPM Moodle application container
│       ├── Dockerfile                   # Custom PHP runtime image
│       ├── entrypoint.sh                # Container initialization script
│       ├── index.php                    # PHP test/application entry point
│       └── testdb.php                   # Database connectivity validation script
│                      
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
└── terraform/                   # Google Cloud infrastructure provisioning
    ├── modules/                 # Reusable Terraform modules
    │   ├── gke/                 # Planned Google Kubernetes Engine resources
    │   └── vpc/                 # Planned Google Cloud network resources
    ├── main.tf                  # Terraform entry point
    ├── outputs.tf               # Terraform outputs
    └── variables.tf             # Terraform input variables
```

## Project Documentation

To keep the repository clean and easy to navigate, the technical operational details have been separated into dedicated engineering logs:

* 📄 **[GCP Terraform Deployment Guide](./gcp_terraform_Deploy.md)** (Terraform / GCP): Provision the Google Cloud infrastructure required for the workload, including VM creation and deployment automation.

* 📄 **[P1 Docker Deployment Guide](./p1_docker_deploy.md)** (Docker Compose / GCP VM): Build and deploy the containerized Moodle environment using Docker Compose on Google Cloud Compute Engine.

* 📄 **[P1 Post-Mortem](./p1_post_mortem.md)** (Docker Compose / GCP VM): Troubleshooting notes, issues encountered, resolutions, and lessons learned during the Docker Compose cloud deployment.

* 📄 **[P2 Kubernetes Deployment Guide](./p2_K8_deploy.md)** (Kubernetes / KinD): Deploy the Moodle application stack into a local Kubernetes environment using KinD.

* 📄 **[P2 Kubernetes Post-Mortem](./p2_post_mortem.md)** (Kubernetes / KinD): Troubleshooting notes covering Kubernetes networking, ingress, storage, scheduling, and deployment issues.

* 📄 **[GCP Terraform Deployment Guide](./gcp_terraform_Deploy.md)** (Terraform / GCP): Provision the Google Cloud infrastructure required for the workload, including VM creation and deployment automation.
---

# Cloud Infrastructure Progression: My Project Journey

This project follows the evolution of the same Moodle application through increasing levels of infrastructure complexity. Rather than building isolated labs, I chose to evolve the same application through multiple deployment models, solving real infrastructure problems along the way.

## Phase 1 – Virtual Cloud Instances & Container Networking (Docker Compose to GCP VM)
### Goal
Build and run a complete Moodle stack using containerized services on cloud infrastructure.
### Architecture & Implementation
I began by containerizing the core application layers and managing them as isolated workloads (Nginx, PHP-FPM, MySQL) on a single virtual host interface. The stack was deployed on a production-grade Linux VM instance (Compute Engine) running natively on Google Cloud. 
### Results & Skills Mastered
Created a working containerized Moodle environment. Engineered private, isolated bridge networks inside Docker Compose so separate container runtimes could communicate securely on the live host instance. Created a working containerized Moodle environment with isolated Docker networking, persistent storage, resource configuration, and cloud firewall rules. This established the foundation for migrating the application into Kubernetes.


## Phase 2 – Local Cluster Orchestration & Debugging (Kubernetes with KinD)
### Goal
Migrate the Docker-based Moodle deployment into a local KinD Kubernetes cluster to implement and validate container orchestration, networking, ingress routing, storage, and application deployment workflows before moving to the cloud.
### Architecture & Implementation
The Docker-based Moodle deployment was migrated into Kubernetes by combining custom container images with declarative Kubernetes objects (Deployments, ClusterIP Services, Persistent Volume Claims, Secrets, ConfigMaps, initContainers, and Ingress routing rules). 
### Results & Skills Mastered
Successfully deployed Moodle as a multi-tier Kubernetes application running locally on KinD within Windows 11/WSL2. Operating locally exposed a number of Windows, Docker, and Kubernetes integration edge cases that required deep-dive troubleshooting. I diagnosed and resolved core engineering bottlenecks, including cross-container network locks, proxy timeout limits, and ingress-to-node scheduling dependencies.


## Phase 3 – Cloud Infrastructure Automation (Future Work)

### Goal

Extend the application deployment model with automated infrastructure provisioning and cloud deployment workflows.

### Planned Architecture & Automation

Future work includes expanding Terraform infrastructure automation, integrating GitHub Actions workflows, using Google Cloud Workload Identity Federation (OIDC) for keyless authentication, and evaluating migration of the Kubernetes deployment to Google Kubernetes Engine (GKE).
