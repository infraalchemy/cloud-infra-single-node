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
│   ├── gcp-gke/                          # Google Kubernetes Engine environment
│   │   ├── storage/                      # Persistent Moodle storage
│   │   │   ├── moodle-storage.yaml       # PersistentVolumeClaim definitions for Moodle data
│   │   │   └── kustomization.yaml        # Kustomize configuration for GKE storage
│   │   │
│   │   ├── mysql/                        # MySQL database
│   │   │   ├── deployment.yaml           # MySQL deployment definition
│   │   │   ├── service.yaml              # Internal Kubernetes service for MySQL
│   │   │   └── kustomization.yaml        # Kustomize configuration for GKE MySQL  
│   │   │
│   │   ├── php/                          # PHP-FPM Moodle application
│   │   │   ├── deployment.yaml           # PHP-FPM application deployment
│   │   │   ├── service.yaml              # Internal service exposing PHP-FPM
│   │   │   └── kustomization.yaml        # Kustomize configuration for GKE PHP   
│   │   │
│   │   ├── nginx/                        # Nginx reverse proxy
│   │   │   ├── configmap.yaml            # Nginx configuration
│   │   │   ├── deployment.yaml           # Nginx reverse proxy deployment
│   │   │   ├── service.yaml              # Internal service exposing Nginx
│   │   │   ├── backendconfig.yaml        # GKE load balancer health-check configuration
│   │   │   └── kustomization.yaml        # Kustomize configuration for GKE Nginx  
│   │   │
│   │   └── overlays/                     # GKE-level configuration
│   │       ├── ingress.yaml              # GKE Ingress configuration for external access
│   │       ├── kustomization.yaml        # Kustomize configuration for GKE Ingress  
│   │       └── managed-cert.yaml         # Google-managed SSL/TLS certificate
│   │
│   └── openshift/                        # Local OpenShift Environment
│       ├── storage/                      # Persistent Moodle storage for OpenShift
│       │   ├── moodle-storage.yaml       # PVC leveraging local OpenShift StorageClasses
│       │   └── kustomization.yaml        # Storage component kustomization
│       │
│       ├── mysql/                        # MySQL database
│       │   └── kustomization.yaml        # Pulls GKE/Kind base config, modifies if needed
│       │
│       ├── php/                          # PHP-FPM Moodle application
│       │   ├── deployment-patch.yaml     # Injects the ServiceAccountName to pass SCC rules
│       │   ├── serviceaccount.yaml       # Grants your init container execution rights
│       │   └── kustomization.yaml        # Ties the PHP patches together
│       │
│       ├── nginx/                        # Nginx reverse proxy
│       │   └── kustomization.yaml        # Pulls base Nginx files
│       │
│       └── overlays/                     # Cluster-wide networking configuration
│           ├── route.yaml                # OpenShift Native Route (Replaces your Ingress)
│           └── kustomization.yaml        # Main entry point to apply the entire stack
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


## Phase 1 – Docker Compose Deployment on GCP

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

## Phase 3 – Managed Kubernetes Deployment on GKE

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
## Phase 4 – Kubernetes Platform on Red Hat OpenShift

### Goal
Extend the architecture proven on GKE to Red Hat OpenShift and demonstrate that the same stateful application design can be adapted across Kubernetes platforms without replacing the underlying workload architecture. The objective was to preserve the separation of Nginx, PHP-FPM, and MySQL while adapting storage, container security, image builds, networking, and application configuration to OpenShift-specific platform requirements.

The deployment was built and validated on the Red Hat Developer Sandbox, providing a managed OpenShift environment for adapting and testing the existing Kubernetes architecture. Existing GKE Kubernetes manifests were carried forward and modified only where platform differences required it, demonstrating application portability while exposing assumptions that had worked on GKE but were incompatible with OpenShift.

The platform continues to use separate Nginx, PHP-FPM, and MySQL workloads, persistent application and database storage, and an init container responsible for preparing the Moodle application files. OpenShift Routes replace GKE Ingress for external application access, with edge TLS termination providing the HTTPS endpoint.
### Result
Built, adapted, and validated the existing Kubernetes application architecture on Red Hat OpenShift while preserving the workload and persistence model established in the earlier phases:

* **Migrated the existing Kubernetes architecture to OpenShift** – retained separate Nginx, PHP-FPM, and MySQL workloads rather than redesigning the application around an OpenShift-specific deployment model
* **Adapted workloads to OpenShift security constraints** – removed fixed-UID and root assumptions exposed by the `restricted-v2` Security Context Constraint and validated workloads using OpenShift-assigned non-root identities
* **Built application images natively within OpenShift** – used BuildConfigs and ImageStreams to build and manage the custom PHP-FPM and Moodle initialization images within the platform
* **Adapted the Moodle initialization process** – replaced runtime package installation with a purpose-built init image compatible with OpenShift's restricted container security model
* **Implemented OpenShift-compatible persistent storage** – used shared RWX storage for Moodle application files and RWO storage for Moodle data and MySQL while preserving state across pod replacement
* **Integrated OpenShift application networking** – connected the OpenShift Route to the Nginx Service using a named service port, with Nginx listening on unprivileged port 8080
* **Established HTTPS using OpenShift edge TLS termination** – configured the Route for TLS termination and HTTP-to-HTTPS redirection while adapting Moodle's proxy configuration for operation behind the OpenShift router
* **Validated end-to-end application routing** – confirmed traffic traverses the OpenShift router, Nginx Service, Nginx workload, PHP-FPM service boundary, Moodle application, and MySQL database
* **Validated workload recovery and persistent state** – deliberately deleted the PHP workload and confirmed OpenShift recreated it while preserving Moodle configuration, HTTPS configuration, application data, and database connectivity
* **Validated database recovery** – deliberately recreated the MySQL workload and verified that the persistent database and Moodle tables remained intact
* **Maintained repeatable Kubernetes configuration with Kustomize** – preserved the existing repository structure while isolating OpenShift-specific manifests and configuration
* **Automated Moodle configuration and validation** – adapted the deployment tooling to retrieve OpenShift service and Route information, perform the Moodle CLI installation, configure reverse-proxy behavior, and verify persistence and external application access

### Engineering Outcome
The OpenShift implementation demonstrates that the application architecture is portable across Kubernetes distributions while also showing that portability does not mean deploying identical manifests unchanged.

Moving from GKE to OpenShift exposed platform-specific differences in container security, storage behavior, image management, service routing, TLS termination, and runtime permissions. Rather than weakening OpenShift security controls or replacing the application architecture, the workloads were adapted to operate within the platform's constraints.

The resulting deployment preserves the same architectural path established in the earlier phases:

**OpenShift Route → Nginx → PHP-FPM → MySQL**

while using OpenShift-native capabilities for image builds, routing, security enforcement, and TLS.

This phase extends the project from Kubernetes deployment into **cross-platform Kubernetes engineering**: identifying platform assumptions, adapting workloads to a stricter security model, troubleshooting service and Route integration, validating persistent state through workload failure and recovery, and maintaining a repeatable architecture across local Kubernetes, GKE, and OpenShift.

The OpenShift implementation also provides a practical foundation for a future Azure Red Hat OpenShift (ARO) deployment, where the same workload architecture and OpenShift-specific adaptations can be carried forward into a managed Azure environment.

---

## Phase 5 – Managed Kubernetes Deployment on Azure

### Goal
Extend the OpenShift architecture validated in the Red Hat Developer Sandbox to Azure Red Hat OpenShift (ARO), following the same progression used when the local KinD implementation was carried forward to GKE.

The objective is to preserve the existing Nginx, PHP-FPM, and MySQL architecture while moving the OpenShift implementation into Azure and adapting the infrastructure, networking, identity, persistent storage, and external application access to the managed cloud environment.

### Planned Work
Provision the required Azure and ARO infrastructure with Terraform and deploy the OpenShift workloads developed and validated in Phase 4.

Carry forward the OpenShift security, image, storage, routing, TLS, persistence, and recovery patterns established in the Developer Sandbox while integrating the Azure services required to support the deployment.

As KinD provided the foundation for the GKE implementation, the Red Hat Developer Sandbox provides the OpenShift foundation for ARO, allowing the project to demonstrate both Kubernetes and OpenShift portability from development environments into managed cloud platforms.