Moodle serves as the stateful application workload for a progressive infrastructure engineering project spanning containerization, Kubernetes orchestration, cloud infrastructure, and automated delivery.

Rather than using a pre-built Moodle image, the application is separated into Nginx, PHP-FPM, and MySQL components with clearly defined responsibilities. Nginx provides the web-facing HTTP layer and routes PHP requests to a custom PHP-FPM application runtime, while MySQL provides the database layer backed by persistent storage.

The same application architecture is progressively evolved across increasingly sophisticated deployment models:

**Docker Compose on GCP → Local Multi-node KinD → Multi-node GKE → AWS/EKS (planned)**

Each phase builds on the previous implementation while introducing additional capabilities in orchestration, persistent state management, networking and ingress, infrastructure as code, cloud services, security, recovery validation, and deployment automation.

---

## Deployment Environment

All infrastructure provisioning and application deployments were initiated from a Windows workstation.

- Workstation: Windows
- Local Linux environment: WSL2
- Container runtime: Docker Desktop
- Local Kubernetes: KinD
- Cloud infrastructure: Google Cloud Platform (GCP)
- Cloud Kubernetes: Google Kubernetes Engine (GKE)
- Infrastructure as Code: Terraform

---

## Repository Structure

*Temporary component-level Kustomizations were used during testing to independently deploy and validate each component.*


```text
├── .github/
│   └── workflows/
│       ├── gcp-gke-deploy.yaml          # GCP/GKE CI/CD deployment workflow
│       └── aws-eks-deploy.yaml          # AWS/EKS CI/CD deployment workflow (in development)
│
├── scripts/
│   ├── deploy-gke.sh                    # GKE application deployment orchestration
│   ├── deploy-infra.sh                  # Infrastructure deployment automation
│   ├── destroy-all.sh                   # Environment teardown automation
│   ├── verify-all.sh                    # Linux deployment validation
│   └── verify-all-win.sh                # Windows deployment validation
│
├── docs/                                 # Engineering documentation
│   ├── gcp_terraform_deploy.md           # GCP VM/infrastructure provisioning guide
│   ├── p1_docker_deploy.md               # docker-compose deployment guide
│   ├── p1_post_mortem.md                 # docker-compose troubleshooting notes
│   ├── p2_k8_deploy.md                   # Kubernetes KinD deployment guide
│   └── p2_post_mortem.md                 # Kubernetes troubleshooting notes
│
├── docker/                               # docker-compose deployment
│   ├── docker-compose.yml                # Moodle multi-container application stack
│   ├── moodledata/                       # Persistent Moodle application data
│   ├── mysql/                            # MySQL database configuration
│   │   └── mysql-data/                   # Persistent MySQL database storage
│   ├── nginx/                            # Nginx reverse proxy container
│   │   ├── Dockerfile                    # Custom Nginx image definition
│   │   └── nginx.conf                    # Nginx configuration
│   └── php/                              # PHP-FPM Moodle application container
│       ├── Dockerfile                    # Custom PHP runtime image
│       ├── entrypoint.sh                 # Container initialization script
│       ├── index.php                     # PHP validation entry point
│       └── testdb.php                    # Database connectivity test
│
├── kubernetes/                           # Kubernetes deployment configurations
│   ├── kind/                             # Local KinD Kubernetes environment
│   │   ├── storage/                      # Persistent Moodle storage
│   │   │   └── moodle-storage.yaml       # Persistent storage configuration
│   │   │
│   │   ├── mysql/                        # MySQL database
│   │   │   ├── deployment.yaml           # MySQL deployment definition
│   │   │   └── service.yaml              # Internal Kubernetes service for MySQL
│   │   │
│   │   ├── php/                          # PHP-FPM Moodle application
│   │   │   ├── deployment.yaml           # PHP-FPM application deployment
│   │   │   └── service.yaml              # Internal service exposing PHP-FPM
│   │   │
│   │   ├── nginx/                        # Nginx reverse proxy
│   │   │   ├── configmap.yaml            # Nginx configuration
│   │   │   ├── deployment.yaml           # Nginx reverse proxy deployment
│   │   │   └── service.yaml              # Internal service exposing Nginx
│   │   │
│   │   └── overlays/                     # KinD-specific configuration
│   │       ├── ingress.yaml              # Local ingress configuration
│   │       ├── kind-config.yaml          # KinD cluster and node configuration
│   │       └── kustomization.yaml        # Kustomize configuration for KinD
│   │
│   └── gcp-gke/                          # Google Kubernetes Engine environment
│       ├── storage/                      # Persistent Moodle storage
│       │   ├── moodle-storage.yaml       # PersistentVolumeClaim definitions for Moodle data
│       │   └── kustomization.yaml        # Kustomize configuration for GKE storage
│       │
│       ├── mysql/                        # MySQL database
│       │   ├── deployment.yaml           # MySQL deployment definition
│       │   ├── service.yaml              # Internal Kubernetes service for MySQL
│       │   └── kustomization.yaml        # Kustomize configuration for GKE MySQL  
│       │
│       ├── php/                          # PHP-FPM Moodle application
│       │   ├── deployment.yaml           # PHP-FPM application deployment
│       │   ├── service.yaml              # Internal service exposing PHP-FPM
│       │   └── kustomization.yaml        # Kustomize configuration for GKE PHP   
│       │
│       ├── nginx/                        # Nginx reverse proxy
│       │   ├── configmap.yaml            # Nginx configuration
│       │   ├── deployment.yaml           # Nginx reverse proxy deployment
│       │   ├── service.yaml              # Internal service exposing Nginx
│       │   ├── backendconfig.yaml        # GKE load balancer health-check configuration
│       │   └── kustomization.yaml        # Kustomize configuration for GKE Nginx  
│       │
│       └── overlays/                     # GKE-level configuration
│           ├── ingress.yaml              # GKE Ingress configuration for external access
│           ├── kustomization.yaml        # Kustomize configuration for GKE Ingress  
│           └── managed-cert.yaml         # Google-managed SSL/TLS certificate
│
├── terraform/                            # Google Cloud infrastructure provisioning
│   ├── docker-compose/                   # P1: GCP VM infrastructure for Docker Compose
│   │   ├── deploy.sh                     # P1 deployment script
│   │   ├── main.tf                       # Compute Engine and firewall resources
│   │   ├── outputs.tf                    # P1 Terraform outputs
│   │   ├── providers.tf                  # Google provider configuration
│   │   ├── startup.sh                    # VM startup and application deployment
│   │   └── variables.tf                  # P1 Terraform variables
│   │
│   └── gcp-gke/                          # P3: GCP infrastructure for GKE
│       ├── main.tf                       # GKE, Artifact Registry, static IP, and APIs
│       ├── outputs.tf                    # GKE infrastructure outputs
│       ├── providers.tf                  # Google provider configuration
│       └── variables.tf                  # GCP project, region, and zone variables
├── Dockerfile                            # Root Moodle application image build
├── README.md                             # Project overview and deployment documentation
└── .gitignore                            # Git ignore rules
```
---

## Project Documentation

To keep the repository organized, deployment guides and troubleshooting notes are maintained separately:

* 📄 **[GCP Terraform Deployment Guide](./docs/gcp_terraform_deploy.md)**
* 📄 **[P1 Docker Deployment Guide](./docs/p1_docker_deploy.md)**
* 📄 **[P1 Post-Mortem](./docs/p1_post_mortem.md)**
* 📄 **[P2 Kubernetes Deployment Guide](./docs/p2_k8_deploy.md)**
* 📄 **[P2 Kubernetes Post-Mortem](./docs/p2_post_mortem.md)**
* 📄 **[P3 GKE Deployment Guide](./docs/p3_k8_deploy.md)**

---

# Infrastructure Evolution

This project demonstrates the progressive design and evolution of a stateful application platform across containerized, Kubernetes, and cloud-native infrastructure.

Rather than treating each environment as a separate deployment, the same Moodle application architecture is carried through every phase—from Docker Compose on a Google Cloud VM, to a customized multi-node KinD cluster, to a multi-node GKE platform, and ultimately to AWS/EKS. Each phase introduces additional infrastructure capabilities while preserving the application's core architecture and persistent data requirements.

The project covers application decomposition, containerization, Kubernetes orchestration, persistent storage, networking and ingress, infrastructure as code, cloud services, identity and security, and CI/CD automation.


## Phase 1 – Containerized Moodle Deployment on GCP

### Goal
Design and deploy the initial stateful application architecture on Google Cloud, establishing the container, networking, and persistence model that would become the foundation for the later Kubernetes implementations.

Instead of using a pre-built Moodle container, the application was decomposed into separate services with clearly defined responsibilities. Nginx provides the web-facing HTTP layer and routes PHP requests to a custom PHP-FPM application runtime. MySQL provides the database layer, backed by persistent storage to preserve database state across container recreation. Docker Compose defines the service relationships, internal networking, persistent storage, and application configuration.

Terraform provisioned the underlying Linux Compute Engine infrastructure, including the VM and supporting network and firewall configuration.

### Result
Built and deployed a complete stateful Moodle stack on Google Cloud with independently managed application, web, and database services.

The deployment established the core architecture used throughout the project: separation of application components, custom image construction, persistent application and database data, service networking, infrastructure provisioning, and external web access.

Rather than being replaced in later phases, this architecture became the baseline that was progressively adapted to Kubernetes and cloud-native infrastructure.

---

## Phase 2 – Multi-Node Kubernetes Deployment with KinD

### Goal
Transform the containerized architecture from Phase 1 into a Kubernetes-native deployment while preserving the same separation between the Nginx web layer, PHP-FPM application runtime, MySQL database, and persistent application data.

A customized local multi-node KinD cluster was built with a control-plane and worker node, creating a more realistic Kubernetes environment than a default single-node cluster. Application components were translated from Docker Compose services into Kubernetes Deployments and Services, using Persistent Volume Claims, Secrets, ConfigMaps, and an init container for storage, configuration, credentials, and application initialization.

Ingress was deliberately scheduled on the worker node and integrated with the host network to provide external HTTPS access from Windows 11/WSL2 into the Kubernetes environment.

### Result
Built and validated a complete stateful application stack on a multi-node Kubernetes cluster, including:

* **Multi-node cluster architecture** – separate control-plane and worker node with workload and ingress placement configured on the worker
* **Kubernetes workload decomposition** – Nginx, PHP-FPM, and MySQL implemented as independently managed workloads and services
* **Persistent state management** – application and database data retained across pod deletion and recreation
* **Application initialization** – init container prepares Moodle application files on persistent storage before runtime startup
* **Configuration and secrets management** – Kubernetes ConfigMaps and Secrets separate application configuration and credentials from workloads
* **Ingress and network routing** – external traffic routed through Kubernetes Ingress to Nginx and then internally to PHP-FPM
* **Workload recovery validation** – pods deliberately recreated to confirm Kubernetes recovery behavior and persistence
* **End-to-end application validation** – verified web access, authentication, database connectivity, HTTPS access, and persistent file uploads

Phase 2 demonstrated that the architecture established with Docker Compose could be successfully decomposed into Kubernetes resources while maintaining application functionality and persistent state. It also established the Kubernetes architecture that would be carried forward into GKE in Phase 3.

---

## Phase 3 – Production-Style Kubernetes Platform on GKE

### Goal
Evolve the architecture proven in the local multi-node KinD environment into a fully integrated GKE platform. The objective was not simply to run Moodle on Kubernetes, but to carry the same stateful application architecture into Google Cloud while solving the infrastructure, storage, networking, security, recovery, and deployment requirements of a cloud Kubernetes environment.

The platform maintains clearly separated Nginx, PHP-FPM, and MySQL workloads rather than relying on a pre-built Moodle image. Nginx provides the web-facing HTTP layer, receiving application traffic and routing PHP requests to PHP-FPM over the Kubernetes service network. A custom PHP-FPM image provides the Moodle application runtime, while MySQL provides the database layer, backed by persistent storage to preserve database state across pod recreation. The init container prepares the Moodle application files on shared persistent storage before the application starts, while persistent application storage preserves application and user data across workload recreation.

Terraform provisions the GKE and supporting Google Cloud infrastructure, while Kustomize manages reusable and environment-specific Kubernetes configuration.

### Result
Built, integrated, and validated an end-to-end multi-node GKE platform spanning application workloads, persistent storage, cloud networking, infrastructure automation, identity, security, and recovery:

* **Designed the application architecture** – separate Nginx, PHP-FPM, and MySQL workloads with clearly defined responsibilities rather than a pre-packaged Moodle deployment
* **Built and published a custom PHP-FPM image** – application runtime packaged and managed through Google Artifact Registry
* **Implemented stateful Kubernetes storage** – persistent application and database storage, including shared RWX storage backed by Google Cloud Filestore
* **Automated application initialization** – init container prepares Moodle files on shared persistent storage before application startup
* **Validated workload recovery and data persistence** – deliberately deleted and recreated application workloads to confirm Kubernetes recovery while preserving application configuration, database state, and uploaded files
* **Provisioned cloud infrastructure with Terraform** – GKE and supporting infrastructure defined as code for repeatable environment creation
* **Structured Kubernetes configuration with Kustomize** – reusable base resources separated from environment-specific configuration
* **Integrated cloud networking** – GKE Ingress, Google Cloud load balancing, and a reserved global static IP provide the external traffic path into the application
* **Established a secure public endpoint** – custom domain, DNS configuration, and Google-managed TLS certificates provide HTTPS access
* **Implemented Kubernetes lifecycle management** – Deployments, Services, PVCs, Secrets, ConfigMaps, health checks, rollout monitoring, and deployment validation
* **Implemented keyless CI/CD authentication** – GitHub Actions authenticates to Google Cloud through Workload Identity Federation (OIDC), eliminating stored long-lived Google Cloud credentials

### Engineering Outcome
The result is more than a Moodle deployment. The same stateful application has been progressively engineered from Docker Compose, through a customized multi-node local Kubernetes cluster, and into an integrated cloud Kubernetes platform.

The GKE implementation demonstrates not only successful deployment, but also **system integration and operational behavior**: application components communicate across defined service boundaries, state survives workload replacement, Kubernetes restores deleted workloads, external traffic traverses the complete ingress path, and the application remains functional after recovery.

Across the three phases, the project demonstrates system decomposition, component integration, state and lifecycle management, infrastructure as code, cloud networking, secure identity, failure recovery, and repeatable deployment practices.

### Current Work
Complete and validate the end-to-end GitHub Actions deployment workflow, including infrastructure provisioning, container image build and push, Kubernetes deployment, rollout verification, and end-to-end application validation.

---

## Phase 4 – Kubernetes Deployment on AWS

### Goal
Extend the same application architecture to AWS to demonstrate cloud portability and apply the infrastructure and Kubernetes patterns developed in GCP to a second cloud provider.

### Planned Work
Provision AWS infrastructure with Terraform and deploy the application to Amazon EKS while integrating AWS-native identity, networking, persistent storage, load balancing, DNS, TLS, and monitoring services.

The application architecture and Kubernetes workload separation will remain consistent, allowing the AWS implementation to demonstrate how the same platform design can be adapted across cloud providers.
