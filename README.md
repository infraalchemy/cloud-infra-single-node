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
---

# Enterprise Moodle Infrastructure Project

## Overview

This project documents my progression from Docker-based deployments to Kubernetes and, eventually, cloud infrastructure.

The goal is to build and understand a complete Moodle deployment while learning how modern DevOps tools work together. Rather than building isolated labs, I chose to evolve the same application through multiple deployment models, solving real infrastructure problems along the way.

Current project progression:

- Docker Compose
- Kubernetes (Kind on Windows 11)
- Google Cloud Platform (planned)

---

## Project Goals

- Deploy Moodle using containers
- Learn Kubernetes by building a complete multi-tier application
- Automate infrastructure using Terraform
- Deploy the same application in Google Cloud
- Build a repeatable environment that can be recreated from source

---

## Current Architecture

```
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

Current environment

- Windows 11
- Docker Desktop
- Kind (Kubernetes in Docker)
- NGINX Ingress
- PHP-FPM
- Moodle
- MySQL
- Persistent Volumes

---

# Project Progression

## Phase 1 – Docker Compose

This project originally began as a Docker Compose deployment.

This phase focused on:

- building container images
- configuring PHP and NGINX
- multi-container networking
- persistent storage
- managing application configuration


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

---

## Phase 2 – Kubernetes (Current)

The Docker deployment is being migrated into Kubernetes using Kind running locally on Windows 11.

Current implementation includes:

- Kubernetes Deployments
- Services
- Ingress
- Persistent Volumes
- Secrets
- ConfigMaps
- MySQL
- Moodle
- PHP-FPM
- NGINX

Running locally has also exposed a number of Windows, Docker and Kubernetes integration issues that required troubleshooting.

See:

- `/docs/kind-troubleshooting.md`

---

## Phase 3 – Google Cloud Platform (Planned)

The next stage is deploying the same application into Google Cloud.

Planned work includes:

- Compute Engine
- Terraform
- Kubernetes
- GitHub Actions
- OIDC authentication
- automated deployments

---

# Repository Structure

```
├── .github/                     # GitHub Actions CI/CD workflows for automated builds
├── docker/                      # Nginx configurations, PHP parameters, and Moodle env variables
├── Dockerfile                   # Multi-stage blueprint compiling Moodle core and PHP dependencies
├── kubernetes/                  # Kubernetes manifests for application deployment
│   ├── base/                    # Core application manifests shared across all environments
│   │   ├── infrastructure/      # Core cluster configuration, routing templates, and base ingress
│   │   ├── jobs/                # Moodle cron engine and database migration tasks
│   │   ├── mysql/               # MySQL StatefulSet and database configurations
│   │   ├── nginx/               # Nginx reverse proxy deployment and server blocks
│   │   ├── php/                 # PHP-FPM deployment and application configurations
│   │   └── storage/             # Persistent Volume Claims for moodledata
│   └── overlays/                # Environment-specific overrides (Kustomize)
│       ├── local-kind/          # Local cluster tweaks (NodePorts, local storage classes, kind-config.yaml)
│       └── prod-gcp/            # GCP GKE configurations (Cloud Load Balancer, persistent cloud disks)
└── terraform/                   # Infrastructure as Code (IaC) for Google Cloud
    ├── modules/                 # Reusable, isolated infrastructure blocks
    │   ├── gke/                 # Google Kubernetes Engine cluster and node pool definitions
    │   └── vpc/                 # Google Cloud VPC networking, subnets, and NAT gateways
    ├── main.tf                  # Root module invoking VPC and GKE architectures
    ├── outputs.tf               # Infrastructure outputs (GKE endpoints, kubeconfig tokens)
    └── variables.tf             # Input variables (GCP Project ID, region, machine types)

```

Each directory represents one part of the deployment pipeline, from local development through cloud infrastructure.

---

# Running Locally

Create the cluster

```bash
kind create cluster --config kubernetes/overlays/local-kind/kind-config.yaml
```

Deploy the application

```bash
kubectl apply -k kubernetes/overlays/local-kind/
```

Additional build and deployment commands are documented in:

```
docs/commands.md
```

---

# Documentation

Additional documentation is kept separate to keep the README focused.

- docs/kind-troubleshooting.md
- docs/architecture.md
- docs/commands.md

---

# Future Work

- Complete Google Cloud deployment
- Expand Terraform modules
- Complete GitHub Actions deployment pipeline
- Improve monitoring and logging
- Expand CI/CD automation

---

## What I Learned

This project has become much more than simply deploying Moodle.

It has helped me understand how Docker, Kubernetes, networking, storage, ingress, infrastructure as code, and cloud services work together. More importantly, it has provided experience troubleshooting issues across multiple layers of the stack rather than simply following tutorials.rnetes Services
* Secrets and configuration management
* Future CI/CD enhancements was not just deployment, but understanding how systems behave and fail across different layers of abstraction.
