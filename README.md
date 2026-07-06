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

This provided the foundation for the Kubernetes migration.

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
.github/
docker/
kubernetes/
terraform/
docs/
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
