# Moodle Infrastructure Project

Docker • Kubernetes • Terraform • Google Cloud

This repository documents the evolution of a Moodle deployment from Docker Compose to a local Kubernetes cluster using Kind, and ultimately to Google Cloud using Terraform and GitHub Actions.

I chose Moodle because it is a stateful, multi-tier application that exercises networking, storage, ingress, initialization, and persistent data. Building the same application across multiple deployment models has provided hands-on experience with modern DevOps and cloud infrastructure practices.

## Technical Architecture

* **Application Stack:** Moodle LMS packaged with custom PHP extensions, Nginx, PHP-FPM, MySQL, and decoupled environment configurations.
* **Local Orchestration:** Kind (Kubernetes in Docker) running on Windows/WSL2 for local Kubernetes development and validation.
* **Infrastructure as Code:** Terraform modules for provisioning Google Cloud infrastructure.
* **CI/CD Automation:** Planned GitHub Actions workflows for automated container image builds and deployments.

## Repository Structure

```text
├── .github/                     # GitHub Actions workflows
├── docker/                      # Docker configurations and application settings
├── Dockerfile                   # Moodle application image build
├── kubernetes/                  # Kubernetes manifests
│   ├── base/                    # Shared Kubernetes resources
│   │   ├── infrastructure/      # Ingress and cluster configuration
│   │   ├── mysql/               # Database deployment
│   │   ├── nginx/               # Nginx reverse proxy
│   │   ├── php/                 # PHP-FPM application layer
│   │   └── storage/             # Persistent storage resources
│   └── overlays/                # Environment-specific configuration
│       ├── local-kind/          # Local Kind deployment
│       └── prod-gcp/            # Planned GCP deployment
└── terraform/                   # Google Cloud infrastructure automation
```

## Project Documentation

* **[Deployment Guide](./deployment.md)**  
  Deployment commands and environment setup instructions.

* **[Verification & Testing Runbook](./post_mortem.md)**  
  Technical challenges encountered during development, including Kubernetes networking, ingress routing, container communication, storage issues, and the solutions implemented.


## Project Progression

This project follows the evolution of the same Moodle application through increasing levels of infrastructure complexity.

## Phase 1 – Containerized Deployment

### Goal

Build and run a complete Moodle stack using containerized services.

### Architecture

The initial deployment used Docker Compose to run:

* Nginx
* PHP-FPM
* Moodle
* MySQL

The application was deployed on a Google Cloud VM environment with Docker networking, persistent volumes, and firewall configuration.

### Result

Created a working containerized Moodle environment and established the foundation for migration into Kubernetes.

---

## Phase 2 – Kubernetes (Kind)

### Goal

Migrate the Docker-based Moodle deployment into a local kind Kubernetes cluster to implement and validate container orchestration, networking, ingress routing, storage, and application deployment workflows before moving to the cloud.

### Architecture

The Docker-based Moodle deployment was migrated into Kubernetes by combining custom container images with Kubernetes orchestration, storage, initialization, and networking components.

The architecture includes:

- Custom Docker image for Moodle/PHP-FPM with Moodle-required PHP extensions and runtime configuration
- Kubernetes Deployments to manage application workloads
- Services for internal communication between application components
- Persistent Volume Claims for Moodle data persistence
- Secrets and ConfigMaps for application configuration
- initContainers to prepare application state during deployment
- Nginx Ingress for external traffic routing
- MySQL database deployment for application data

The final local environment combines containerized application builds with Kubernetes-managed storage, networking, and lifecycle operations.

### Challenges

Building the local Kubernetes environment required troubleshooting across multiple layers:

* Windows and Docker Desktop networking
* Kind node port mappings
* Ingress routing and scheduling
* PHP-FPM container communication
* initContainer initialization
* Persistent storage
* Application resource tuning

### Result

Successfully deployed Moodle as a multi-tier Kubernetes application running locally on Kind with persistent storage and ingress routing.

---

## Phase 3 – Google Cloud Kubernetes Deployment

### Goal

Move the validated Kubernetes architecture into Google Cloud using managed Kubernetes and infrastructure automation.

### Planned Architecture

* Google Kubernetes Engine (GKE)
* Terraform-managed infrastructure
* Google Cloud networking
* Persistent cloud storage
* Automated deployments through GitHub Actions

The goal is to continue evolving the local Kubernetes deployment into a repeatable cloud deployment pipeline.
