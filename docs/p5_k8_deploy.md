# Phase 5 Deployment Runbook: Cloud Kubernetes Deployment with Azure Red Hat OpenShift (ARO)

This guide documents the process used to provision, deploy, validate, and tear down the Moodle environment on Azure Red Hat OpenShift (ARO). The deployment carries forward the separation of Nginx, PHP-FPM, and MySQL from earlier phases, adapting container images, storage, security, and external routing to ARO. Terraform manages the Azure infrastructure, Azure Container Registry (ACR) stores the custom images, and OpenShift deploys the application workloads.

---

# Prerequisites

Required software:

* Azure CLI (`az`)
* Terraform
* OpenShift CLI (`oc`)
* Docker Desktop (running for local image builds)
* Git
* Bash

Verify installations:

```bash
az version
terraform version
oc version --client
docker --version
git --version
```

Run repository-relative commands from the repository root unless otherwise stated. The Azure subscription must support ARO and have sufficient regional compute quota. ARO provisioning may fail if the required vCPU quota is unavailable.

---

# Azure Environment Setup

Authenticate to Azure:
```bash
az login
```

Verify the active subscription:
```bash
az account show --output table
```

If necessary, select the intended subscription before provisioning:
```bash
az account set --subscription "<SUBSCRIPTION-ID>"
az account show --output table
```

---

## Register Azure Red Hat OpenShift Resource Provider

Check whether the ARO resource provider is registered:
```bash
az provider show \
  --namespace Microsoft.RedHatOpenShift \
  --query "{Provider:namespace, State:registrationState}" \
  --output table
```

*Initial result observed:*
```text
Provider                  State
------------------------  -------------
Microsoft.RedHatOpenShift NotRegistered
```

Register the provider:
```bash
az provider register --namespace Microsoft.RedHatOpenShift
```

Registration can take time. Monitor its status:
```bash
az provider show \
  --namespace Microsoft.RedHatOpenShift \
  --query "{Provider:namespace, State:registrationState}" \
  --output table
```

Inspect the full provider details if needed:
```bash
az provider show -n Microsoft.RedHatOpenShift
```

*Expected before provisioning:* `Registered`.

---

# Deployment Workflow

The deployment follows this sequence:

1. Authenticate to Azure and verify the subscription.
2. Register the ARO resource provider and confirm prerequisites.
3. Supply the Terraform service principal credentials.
4. Provision the Azure infrastructure and ARO cluster using Terraform.
5. Verify the ARO cluster and connect using the OpenShift CLI.
6. Run the ARO pre-deployment script.
7. Build the custom PHP-FPM and Moodle initialization images.
8. Push both images to Azure Container Registry.
9. Verify Kubernetes secrets and deploy persistent storage.
10. Deploy MySQL, PHP-FPM, and Nginx.
11. Deploy the OpenShift Route configuration.
12. Run verification and Moodle configuration scripts.
13. Configure and verify the external domain using the separate domain guide.
14. Validate workload security, application routing, and deployment health.
15. Tear down the environment when no longer required.

---

# Terraform Infrastructure Provisioning

## Configure Terraform Service Principal Credentials

Terraform requires the ARO service principal credentials used by the infrastructure configuration. Restore the client ID for the current shell session:
```bash
export TF_VAR_aro_client_id="<ARO-SERVICE-PRINCIPAL-CLIENT-ID>"
```

Read the client secret without echoing it to the terminal:
```bash
read -s -p "Enter ARO service principal secret: " TF_VAR_aro_client_secret
echo
export TF_VAR_aro_client_secret
```

Verify both variables are populated without printing their values:
```bash
test -n "$TF_VAR_aro_client_id" && echo "ARO client ID is set"
test -n "$TF_VAR_aro_client_secret" && echo "ARO client secret is set"
```

*Note:* These variables must be available in the shell running Terraform. Do not commit secrets to the repository or include their values in documentation.

---

## Initialize and Validate Terraform

From the directory containing the ARO Terraform configuration, initialize Terraform:
```bash
terraform init
```

Format and validate the configuration:
```bash
terraform fmt
terraform validate
```

If formatting has already been applied, check it without modifying files:
```bash
terraform fmt -check
```

Review the infrastructure changes:
```bash
terraform plan
```

Apply the reviewed configuration:
```bash
terraform apply
```

*Observed result from the initial deployment:*
```text
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.
```

*Note:* The resource count is specific to the applied configuration. It can differ after configuration changes.

---

## Verify Terraform Resources

Inspect the resources tracked in Terraform state:
```bash
terraform state list
```

Confirm that the expected Azure infrastructure resources appear. The number of state entries does not always equal the `Resources: ... added` count, because existing or previously managed resources can also be present in state.

---

# Verify Azure Red Hat OpenShift Cluster

Check whether the ARO cluster has provisioned successfully:
```bash
az aro list \
  --resource-group rg-moodle-aro \
  --query "[].{Name:name,State:provisioningState}" \
  -o table
```

*Result:*
```text
Name                State
------------------  ---------
moodle-aro-cluster  Succeeded
```

Retrieve the ARO API endpoint:
```bash
az aro show \
  --name moodle-aro-cluster \
  --resource-group rg-moodle-aro \
  --query "apiserverProfile.url" \
  -o tsv
```

*Result:*
```text
https://api.moodle-aro.centralus.aroapp.io:6443/
```

---

# OpenShift Authentication and Pre-Deployment Setup

## Set Moodle Credentials for the Deployment Session

Prompt for the credentials required by the deployment scripts without displaying them:
```bash
read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
echo
read -s -p "Enter Moodle database password: " MOODLE_DB_PASSWORD
echo
read -s -p "Enter Moodle administrator password: " MOODLE_ADMIN_PASSWORD
echo

export MYSQL_ROOT_PASSWORD MOODLE_DB_PASSWORD MOODLE_ADMIN_PASSWORD
```

Verify the variables are set:
```bash
test -n "$MYSQL_ROOT_PASSWORD" && echo "MySQL root password is set"
test -n "$MOODLE_DB_PASSWORD" && echo "Moodle database password is set"
test -n "$MOODLE_ADMIN_PASSWORD" && echo "Moodle admin password is set"
```

*Note:* Use the intended credentials for the deployment. If reusing existing persistent MySQL data, changing an environment variable or Secret does not automatically change the password stored in the database.

---

## Run ARO Pre-Deployment Script

Run the repository's ARO pre-deployment script:

```bash
bash scripts/pre-deploy-aro.sh
```

*Observed output included:*

```text
Login Succeeded
```

This script was used to prepare the OpenShift deployment session. Consult the script itself for its exact authentication, namespace, and secret operations; those internals are not reproduced here.

Verify OpenShift authentication:
```bash
oc whoami
```

*Result:*
```text
kube:admin
```

Verify the current OpenShift project:
```bash
oc project
```

*Result:*
```text
Using project "moodle" on server "https://api.moodle-aro.centralus.aroapp.io:6443".
```

---

# Azure Container Registry and Custom Images

The deployment uses two custom images built from project Dockerfiles: `custom-php:8.2` for the PHP-FPM runtime and `moodle-init:8.2` for the initialization container. Both are published to ACR for use by the ARO workloads.

*Note:* Ensure Docker Desktop is running before building the images.

## Authenticate Docker to Azure Container Registry
```bash
az acr login --name moodlearoregistry
```

*Expected:*
```text
Login Succeeded
```

---

## Build Custom PHP-FPM Image

From the repository root, build the custom PHP image directly from its Dockerfile:
```bash
docker build \
  --no-cache \
  -t moodlearoregistry.azurecr.io/custom-php:8.2 \
  ./docker/php
```

The `--no-cache` flag forces the image build steps to run without reusing Docker's build cache.

---

## Build Moodle Initialization Image

Build the separate Moodle initialization image:
```bash
docker build \
  --no-cache \
  -t moodlearoregistry.azurecr.io/moodle-init:8.2 \
  ./kubernetes/azure-aro/images/moodle-init
```

Both images are built from their respective Dockerfiles rather than simply retagging existing local images.

---

## Push Custom Images to ACR

Push the PHP-FPM image:
```bash
docker push moodlearoregistry.azurecr.io/custom-php:8.2
```

Push the Moodle initialization image:
```bash
docker push moodlearoregistry.azurecr.io/moodle-init:8.2
```

---

## Verify Images in Azure Container Registry

List the repositories in ACR:
```bash
az acr repository list \
  --name moodlearoregistry \
  --output table
```

*Result:*
```text
Result
-----------
custom-php
moodle-init
```

Optionally inspect the tags for each image:
```bash
az acr repository show-tags --name moodlearoregistry --repository custom-php --output table
az acr repository show-tags --name moodlearoregistry --repository moodle-init --output table
```

*Expected:* Both repositories include the `8.2` tag.

---

# Workload Deployment Phase

Deploy the application components in dependency order: persistent storage, MySQL, PHP-FPM, Nginx, and OpenShift networking. Ensure the deployment secrets and registry pull credentials are configured before starting workloads that depend on them.

## Verify Kubernetes Secrets

Verify the application secrets:
```bash
oc get secret mysql-secret php-secret -n moodle
```

Also confirm that the image pull secret required by the workload service account exists, if the manifests use a private-registry pull secret:
```bash
oc get secret acr-pull-secret -n moodle
```

*Note:* The secret names and contents must match the workload manifests and pre-deployment script. A Secret existing does not by itself prove its keys or credentials are correct.

---

## Deploy Persistent Storage

Apply the ARO persistent storage manifests:
```bash
oc apply -k kubernetes/azure-aro/storage
```

Verify the persistent volume claims:
```bash
oc get pvc -n moodle
```

Confirm the expected Moodle application files, Moodle data, and MySQL storage claims are present. Claims using delayed binding may remain `Pending` until a consuming pod is scheduled.

---

## Deploy MySQL Database

```bash
oc apply -k kubernetes/azure-aro/mysql
```

Verify the deployment and pods:
```bash
oc get deployment mysql -n moodle
oc get pods -n moodle
```

Wait for the database deployment to become available:
```bash
oc rollout status deployment/mysql -n moodle
```

---

## Deploy PHP-FPM Application

```bash
oc apply -k kubernetes/azure-aro/php
```

Verify the PHP deployment:
```bash
oc rollout status deployment/php -n moodle
```

Inspect the application image and init container image configured in the deployment:
```bash
oc get deployment php -n moodle \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{": "}{.image}{"\n"}{end}{range .spec.template.spec.initContainers[*]}{.name}{": "}{.image}{"\n"}{end}'
```

Verify that the workload uses the intended images from `moodlearoregistry.azurecr.io`.

---

## Deploy Nginx Web Server

```bash
oc apply -k kubernetes/azure-aro/nginx
```

Verify the Nginx deployment:
```bash
oc rollout status deployment/nginx -n moodle
```

Inspect the Nginx service:

```bash
oc get svc nginx -n moodle
```

---

## Deploy OpenShift Networking Overlay

Apply the ARO overlay resources, including the application's Route configuration:
```bash
oc apply -k kubernetes/azure-aro/overlays
```

Verify the Route:
```bash
oc get route moodle-custom -n moodle
```

Inspect its host, target service, and TLS settings:
```bash
oc describe route moodle-custom -n moodle
```

---

# Run Automated Deployment Verification

Execute the repository's OpenShift verification script:
```bash
bash scripts/verify-openshift.sh
```

This script was used as part of the deployment verification workflow. Review its current contents for the precise checks and pass/fail conditions.

Inspect the workload resources directly:

```bash
oc get pods -n moodle
oc get deployments -n moodle
oc get svc -n moodle
oc get pvc -n moodle
oc get routes -n moodle
```

---

# Configure Moodle for ARO

Run the automated ARO Moodle configuration script:

```bash
bash scripts/configure-moodle-aro.sh
```

This script was used to complete Moodle application configuration after the OpenShift workloads were deployed. Its exact internal installation and configuration steps should be checked against the script version used for this deployment.

Verify the application deployment after the script completes:
```bash
oc get pods -n moodle
oc get route moodle-custom -n moodle
```

---

# Configure Domain DNS

The custom domain configuration is documented separately in the BCC domain setup file. Use that document for the domain's DNS record changes and verification.

## Retrieve the ARO Application Router IP

```bash
oc get svc router-default -n openshift-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'
```

*Router IP:*
```text
<IP Address>
```

*Note:* This is the application ingress router address observed during this deployment, not a guaranteed permanent address after infrastructure destruction and recreation. Retrieve it again after rebuilding the cluster.

---

## Verify the ARO API Endpoint

Display the OpenShift API server address:
```bash
oc whoami --show-server
```

Check name resolution for the ARO API hostname:
```bash
nslookup api.moodle-aro.centralus.aroapp.io
```

*Addresses recorded during the deployment:*

```text
64.xx.xxx.xx   Local Shaw DNS resolver
4.xxx.xxx.xx   ARO API endpoint
52.xxx.xxx.xxx ARO application router
```

The API endpoint and application router serve different purposes: `oc` communicates with the cluster API, while external Moodle web requests enter through the application router. The resolver address is the DNS server queried by the workstation, not an ARO endpoint.

---

# Verify OpenShift Container Security Context

OpenShift assigns a runtime UID under its security constraints. Verify the effective identity inside each workload:

```bash
for deploy in nginx php mysql; do
  echo "=== $deploy ==="
  oc exec -n moodle deployment/$deploy -- id
done
```

*Result:*
```text
=== nginx ===
uid=1000730000(1000730000) gid=0(root) groups=0(root),1000730000
=== php ===
Defaulted container "php" out of: php, init-moodle (init)
uid=1000730000(1000730000) gid=0(root) groups=0(root),1000730000
=== mysql ===
uid=1000730000(1000730000) gid=0(root) groups=0(root),1000730000
```

The result demonstrates that these workload processes ran with the OpenShift-assigned non-root UID. The `gid=0(root)` entry identifies group membership; it does not mean the process ran as UID 0.

---

# Verify Application Routing

Inspect the application Route:
```bash
oc get route moodle-custom -n moodle
```

Retrieve its hostname:
```bash
oc get route moodle-custom -n moodle \
  -o jsonpath='{.spec.host}{"\n"}'
```

Test HTTPS response headers using the Route hostname:
```bash
ROUTE_HOST=$(oc get route moodle-custom -n moodle -o jsonpath='{.spec.host}')
curl -I --max-time 15 "https://$ROUTE_HOST"
```

*Expected:* A successful HTTP response or an intentional application redirect. A `200` response confirms an HTTP response from the endpoint; a `301` or `302` should be followed and checked for a successful final destination. An HTTP response alone does not validate Moodle functionality or persistence.

---

# Verify Application Access

Access Moodle through the HTTPS domain configured in the separate BCC domain guide.

Verify the deployment remains healthy:
```bash
oc get pods -n moodle
oc get pvc -n moodle
oc get route moodle-custom -n moodle
```

For functional validation, check that Moodle loads, the administrator can sign in, and existing application data remains available. A persistence test should include verifying that uploaded files and database content survive workload pod replacement. These checks are recommended here; the supplied Phase 5 notes do not include recorded functional test output.

---

# Troubleshooting: MySQL Pod Recovery

During deployment troubleshooting, the MySQL deployment was scaled down:

```bash
oc scale deployment/mysql --replicas=0 -n moodle
```

This is **not** part of the normal deployment sequence. Scaling to zero stops MySQL and interrupts application database access. It does not remove persistent data if the associated PVC remains intact.

When recovery is appropriate, scale the deployment back up:
```bash
oc scale deployment/mysql --replicas=1 -n moodle
oc rollout status deployment/mysql -n moodle
```

Inspect the pod and logs if it does not become ready:
```bash
oc get pods -n moodle
oc logs deployment/mysql -n moodle
```

*Note:* The original notes mention removing a bad pod but show a scale-to-zero command. Scaling down and deleting a failed pod are different recovery operations; use the action appropriate to the actual failure.

---

# Destroy ARO Environment

Terraform was used to manage the Azure infrastructure lifecycle. Review the destroy plan before removing the cluster and associated resources.

## Review Terraform Destroy Plan

From the Terraform configuration directory:

```bash
terraform plan -destroy
```

Confirm that the listed resources belong to this environment. Destroying infrastructure can remove the ARO cluster, workloads, and infrastructure-managed storage, and may cause permanent data loss.

---

## Verify Azure Resource Cleanup

Check whether the ARO cluster remains:
```bash
az aro list \
  --resource-group rg-moodle-aro \
  --output table
```

Check for remaining resources in the deployment resource group, if it still exists:
```bash
az resource list \
  --resource-group rg-moodle-aro \
  --output table
```

Review any remaining managed resource groups, disks, public IP addresses, networking resources, and ACR resources in Azure before assuming billing has stopped. Resources not managed by the Terraform state may need separate cleanup. Preserve the ACR repository if it will be reused in a future deployment.

---

# Maintenance: Reconnect to ARO

For an existing cluster, retrieve its API endpoint again:

```bash
az aro show \
  --name moodle-aro-cluster \
  --resource-group rg-moodle-aro \
  --query "apiserverProfile.url" \
  -o tsv
```

Reauthenticate using the approved OpenShift login method or the repository's pre-deployment script, then verify the session:

```bash
oc whoami
oc project moodle
oc get pods -n moodle
```

---

## Destroy Terraform-Managed Infrastructure

After reviewing the plan and confirming that required data is backed up:
```bash
terraform destroy
```

*Note:* The supplied deployment notes record `terraform plan -destroy` but do not include the output of an executed `terraform destroy`. This command is the teardown step to run when intentionally removing the environment.

---

# Deployment Notes

* Terraform provisioning returned **8 added, 0 changed, 0 destroyed** in the recorded initial apply.
* The ARO cluster `moodle-aro-cluster` reported provisioning state **Succeeded**.
* Both custom images, `custom-php` and `moodle-init`, appeared in Azure Container Registry.
* The application uses the `moodle` OpenShift project and the `moodle-custom` Route.
* Nginx, PHP, and MySQL were verified running under the OpenShift-assigned non-root UID `1000730000`.
* Domain configuration is maintained in the separate BCC domain document.
* Final application functional test results and completed Terraform destroy output were not included in the supplied Phase 5 notes.
