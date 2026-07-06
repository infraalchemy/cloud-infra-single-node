Moodle Infrastructure Project
Overview

This project shows the progression of running the same application (Moodle) across three environments:

Docker Compose (initial setup at work)
Kubernetes using Kind (local Windows 11 environment)
Google Cloud Platform (planned deployment)

The goal wasn’t just to get Moodle running, but to understand how infrastructure changes as you move from local containers → orchestration → cloud.

Architecture

High-level flow of the current Kubernetes setup:

Browser
   ↓
Ingress Controller (NGINX)
   ↓
Kubernetes Service
   ↓
PHP-FPM Pod
   ↓
Moodle Application Container
   ↓
Persistent Volume (storage)

Local environment runs on Windows 11 using Kind + Docker Desktop.

Project Phases
Phase 1 – Docker Compose (PaNGlobal)

Initial deployment using Docker Compose in a work environment.

Focused on:

containerizing Moodle
PHP + NGINX setup
volumes and persistence
basic service networking

This provided the foundation for the Kubernetes migration.

Phase 2 – Kubernetes (Kind on Windows 11)

Rebuilt the same system using Kubernetes locally.

Stack:

Windows 11 host
Docker Desktop
Kind cluster
NGINX Ingress Controller
PHP-FPM + Moodle pods
persistent volumes

This phase introduced real orchestration challenges and multi-layer debugging across Kubernetes, containers, and the Windows host environment.

👉 Full troubleshooting details are in: /docs/kind-troubleshooting.md

Phase 3 – Google Cloud Platform (Planned)

Next step is deploying the same system into a cloud environment using GCP.

Focus will include:

Compute Engine VM setup
Docker deployment on Linux
firewall + networking configuration
running outside local Kubernetes
How to Run (Kind – Local Kubernetes)
1. Create cluster
kind create cluster --config kind-config.yaml --name lab
2. Build image
docker build -t moodle-custom:latest .
3. Load image into cluster
kind load docker-image moodle-custom:latest --name lab
4. Deploy ingress
kubectl apply -f ingress-nginx.yaml
5. Deploy application
kubectl apply -f k8s/
6. Verify deployment
kubectl get pods
kubectl get svc
kubectl get ingress
Troubleshooting & Deep Dive

All detailed issues and fixes are documented separately:

/docs/kind-troubleshooting.md – real Kubernetes + Windows + networking issues
/docs/architecture.md – deeper explanation of system design and components
Result

A fully working Moodle deployment running locally on a Kubernetes (Kind) cluster, accessible through Ingress, with working storage, networking, and application configuration.

The environment can be fully destroyed and recreated using the steps above.

Notes

This project was built in phases to understand infrastructure progression:

Docker Compose → Kubernetes (Kind) → Google Cloud

Each phase builds on the previous one and introduces more realistic infrastructure challenges.

The main focus was not just deployment, but understanding how systems behave and fail across different layers of abstraction.