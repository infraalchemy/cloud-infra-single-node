# Azure Red Hat OpenShift Deployment Post-Mortem

Deploying the stateful Moodle application to Azure Red Hat OpenShift (ARO) introduced infrastructure provisioning, identity and access, storage, image registry, and container security challenges. This document captures the problems encountered while adapting the existing OpenShift deployment to Azure, the troubleshooting performed, and the resulting fixes or outstanding findings.

## 1. Azure Resource Provider Registration and Regional vCPU Quotas

* **The Problem:** The new Azure subscription was not immediately ready to provision an ARO cluster. The `Microsoft.RedHatOpenShift` resource provider was initially unregistered, and regional compute quotas were too low for the intended cluster.
* **The Cause:** A new subscription does not necessarily have every required Azure resource provider registered or enough regional VM-family quota. Initial checks showed a DSv5-family quota of four vCPUs in Canada Central, below the requirements for the planned ARO environment.
* **The Fix:** Registered the required providers, inspected regional quotas, and requested the needed quota increase. Subsequent notes show a Central US DSv5-family quota of 48 vCPUs; the deployment proceeded in `centralus`.

```bash
az provider register --namespace Microsoft.RedHatOpenShift
az provider register --namespace Microsoft.Compute

az vm list-usage --location canadacentral \
  --query "[?contains(name.value, 'standardDSv5Family')]" \
  --output table

az vm list-usage --location centralus --output table
```

---

## 2. ARO Cluster Provisioning Blocked by Virtual Network Permissions

* **The Problem:** Terraform failed while creating `moodle-aro-cluster`, reporting `InvalidResourceProviderPermissions`.
* **The Cause:** The Azure Red Hat OpenShift resource-provider service principal lacked the required permissions on `vnet-moodle-aro`. Granting the Terraform service principal Contributor access did not, by itself, grant the separate ARO resource-provider identity access to the virtual network.
* **The Fix:** Retrieved the VNet resource ID and granted the ARO resource-provider service principal the `Network Contributor` role at that scope. The failed ARO cluster object was then deleted before retrying provisioning, while preserving the other Terraform-managed infrastructure.

```bash
VNET_ID=$(az network vnet show \
  --resource-group rg-moodle-aro \
  --name vnet-moodle-aro \
  --query id --output tsv)

# Use the ARO resource-provider principal ID identified in the Azure error.
MSYS_NO_PATHCONV=1 az role assignment create \
  --assignee "<ARO_RESOURCE_PROVIDER_PRINCIPAL_ID>" \
  --role "Network Contributor" \
  --scope "$VNET_ID"

az aro show \
  --name moodle-aro-cluster \
  --resource-group rg-moodle-aro \
  --query "{name:name,provisioningState:provisioningState}" \
  --output table
```

The failed cluster was removed using `az aro delete` before a new Terraform apply. The `MSYS_NO_PATHCONV=1` prefix prevented Git Bash from rewriting the Azure resource ID path.

---

## 3. Terraform Provisioning Timeout and Missing State Entry

* **The Problem:** Terraform reported `context deadline exceeded` while creating the ARO cluster. Azure later showed the cluster in a successful state, but the cluster resource was missing from Terraform state.
* **The Cause:** The Azure cluster provisioning operation continued beyond Terraform's polling window. A resource could therefore exist in Azure without having been recorded in the local Terraform state, leaving subsequent plans and teardown operations incomplete.
* **The Fix:** Compared the Azure resource status with Terraform state and imported the existing ARO cluster into the expected Terraform resource address. The import returned `Import successful!`, after which the state was checked again.

```bash
az aro show \
  --name moodle-aro-cluster \
  --resource-group rg-moodle-aro \
  --query "{state:provisioningState,apiServer:apiserverProfile.url}" \
  --output table

terraform state list

MSYS_NO_PATHCONV=1 terraform import \
  azurerm_redhat_openshift_cluster.aro \
  "<FULL_AZURE_ARO_CLUSTER_RESOURCE_ID>"

terraform state list
```

This recovery was important for eventual `terraform destroy`: Terraform cannot reliably manage an existing resource that is absent from its state.

---

## 4. Persistent Volume Claims Blocked by Incompatible Storage Classes

* **The Problem:** Application pods could not schedule, with Kubernetes reporting unbound PersistentVolumeClaims and `FailedScheduling`.
* **The Cause:** The manifests had been carried forward from the previous OpenShift environment, but the referenced storage classes did not match the storage available in ARO.
* **The Fix:** Updated the ARO storage manifests to use Azure-backed classes, then reapplied the PVCs. The recorded ARO output showed `moodle-pvc` bound using `azurefile-csi` with RWX access; `moodledata-pvc` and `mysql-pvc` initially remained pending on `managed-csi` until their consuming workloads could be scheduled.

```bash
oc get storageclass
oc get pvc

# Used during troubleshooting to recreate claims with corrected classes.
# WARNING: Deleting PVCs may delete their underlying data.
oc delete pvc moodle-pvc moodledata-pvc mysql-pvc
oc apply -k kubernetes/azure-aro/storage

oc get pvc
```

The PVC deletion was a recovery action, **not** a normal redeployment step. Storage must be inspected and backed up before removing existing claims.

---

## 5. MySQL Pod Blocked by a Missing Kubernetes Secret

* **The Problem:** MySQL failed to start with `Error: secret "mysql-secret" not found`.
* **The Cause:** The MySQL Deployment referenced secret keys that were not yet present in the target ARO namespace. The deployment also required specific key names, so merely having passwords available in the shell was insufficient.
* **The Fix:** Created `mysql-secret` with the expected `root-password` and `moodleuser-password` keys and verified the secret existed. The subsequent pod output showed MySQL running.

```bash
read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD; echo
read -s -p "Enter Moodle database password: " MOODLE_DB_PASSWORD; echo

oc create secret generic mysql-secret \
  --from-literal=root-password="$MYSQL_ROOT_PASSWORD" \
  --from-literal=moodleuser-password="$MOODLE_DB_PASSWORD" \
  --dry-run=client -o yaml | oc apply -f -

oc get secret mysql-secret
oc get pods

unset MYSQL_ROOT_PASSWORD MOODLE_DB_PASSWORD
```

---

## 6. Private Azure Container Registry Image Pull Failures

* **The Problem:** The PHP workload could not pull its custom images from Azure Container Registry (ACR), even though both repositories existed. The image pull returned `unauthorized: authentication required`.
* **The Cause:** Building and pushing `custom-php:8.2` and `moodle-init:8.2` to ACR did not automatically give the ARO workload permission to retrieve them. Both Azure registry authorization and Kubernetes image-pull credentials were needed.
* **The Fix:** Granted the deployment identity `AcrPull` on the registry, created `acr-pull-secret` in OpenShift, linked it to `moodle-aro-sa`, and restarted the PHP Deployment. The init-container logs and pod state were then monitored.

```bash
ACR_ID=$(az acr show \
  --name moodlearoregistry \
  --query id --output tsv)

MSYS_NO_PATHCONV=1 az role assignment create \
  --assignee "$TF_VAR_aro_client_id" \
  --role "AcrPull" \
  --scope "$ACR_ID"

oc create secret docker-registry acr-pull-secret \
  --docker-server=moodlearoregistry.azurecr.io \
  --docker-username="$TF_VAR_aro_client_id" \
  --docker-password="$TF_VAR_aro_client_secret" \
  --dry-run=client -o yaml | oc apply -f -

oc secrets link moodle-aro-sa acr-pull-secret --for=pull
oc rollout restart deployment/php
oc get pods -w
oc logs -l app=php -c init-moodle -f
```

The `AcrPull` role authorized the Azure identity, while the OpenShift pull secret supplied the workload with credentials to authenticate to the private registry.

---

## 7. OpenShift Project Isolation and Container Security

* **The Problem:** During deployment verification, PHP-FPM and MySQL were found running as `UID 0 (root)`, while Nginx ran as `UID 101`. This was inconsistent with the expected OpenShift restricted security model, where application containers should run using assigned non-root user IDs.

* **The Cause:** The workloads had initially been deployed into OpenShift's built-in `default` project rather than a dedicated application project. This complicated the investigation of Security Context Constraints (SCCs), service account permissions, and container execution identities. The deployment was not using the intended isolated namespace configuration.

* **The Fix:** Created a dedicated OpenShift project named `moodle` and deployed the application workloads within that project. This established a separate security and resource boundary for Moodle and allowed the workloads to run under OpenShift-assigned non-root identities.

```bash
oc new-project moodle
```bash

Verify the active project:
```bash
oc project
```

Check who can use the anyuid SCC:
```bash
oc adm policy who-can use scc anyuid
```

Identify the SCC assigned to the PHP pod
```bash
oc get pod -l app=php \
  -o jsonpath='{.items[0].metadata.annotations.openshift\.io/scc}{"\n"}'
```

Verify the runtime user identities:
```bash
for deploy in nginx php mysql; do
  echo "=== $deploy ==="
  oc exec -n moodle deployment/$deploy -- id
done
```

Result:
```text
=== nginx ===
uid=1000730000(1000730000) gid=0(root) groups=0(root),1000730000
=== php ===
uid=1000730000(1000730000) gid=0(root) groups=0(root),1000730000
=== mysql ===
uid=1000730000(1000730000) gid=0(root) groups=0(root),1000730000
```

* **Validation:** All three application containers were verified running under the non-root UID 1000730000, confirming the expected runtime security behavior within the dedicated Moodle project.
* **Lesson Learned:** OpenShift workloads should be deployed into dedicated application projects rather than the built-in default project. Project isolation provides namespace-specific security boundaries, supports controlled service account permissions, and allows OpenShift to assign and enforce the appropriate runtime security context. The successful non-root validation confirmed the resolution, although the original SCC admission behavior was not conclusively traced.

---

## 8. Deployment Recovery and Rebuild Verification

* **The Problem:** Recreating an ARO cluster required renewed OpenShift authentication, correct namespace selection, registry access, and careful ordering of dependent resources. Existing terminal sessions and image references could point to a previous cluster or the former OpenShift image registry.
* **The Cause:** ARO cluster recreation generates a new administrative credential context, while the application manifests still contained references inherited from the prior `dolliebears-dev` OpenShift deployment during initial adaptation.
* **The Fix:** Retrieved the current ARO cluster credentials, authenticated with `oc`, verified the active project, rebuilt both custom images from their Dockerfiles, published them to ACR, and deployed storage, MySQL, PHP, Nginx, and Route resources in sequence. The deployment scripts then handled application configuration and verification.

```bash
az aro list-credentials \
  --name moodle-aro-cluster \
  --resource-group rg-moodle-aro

oc whoami
oc project

az acr repository list --name moodlearoregistry --output table

oc get pvc
oc get pods
oc get routes

bash scripts/verify-openshift.sh
bash scripts/configure-moodle-aro.sh
```

The notes record successful ACR repository verification, cluster access, and later non-root UID checks. They do not provide a complete end-to-end application test log for every rebuild, so no additional validation results are assumed here.
