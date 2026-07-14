# Infrastructure Migration Post-Mortem

Deploying the infrastructure architecture to Google Cloud Platform (GCP) from a new system environment introduced several challenges involving authentication, Terraform state management, project configuration, billing, API enablement, and IAM permissions.

---

## 1. Google Cloud Authentication and Account Context

* **The Problem:** Working from a fresh system environment required re-establishing the Google Cloud CLI authentication context.

* **The Cause:** The local environment did not contain the correct Google Cloud credentials and project context for the intended deployment account.

* **The Fix:** Authenticate the Google Cloud CLI:

This opens a browser-based authentication flow. Complete the sign-in process using the intended Google Cloud account.
```bash
gcloud auth login
```

Verify the authenticated account.
```bash
gcloud auth list
```
	Expected output:
	```text
	ACTIVE  ACCOUNT
    *       <YOUR_GOOGLE_ACCOUNT>
    ```
	
Authenticate Terraform and Google Cloud client libraries.
```bash
gcloud auth application-default login
```

---


## 2. Terraform State and Project ID Mismatch

* **The Problem:** Terraform returned a `403 Forbidden` error during `terraform plan` and referenced an obsolete GCP project ID that no longer existed in the current configuration.

* **The Cause:** Terraform was still tracking resources from a previous project through its local state files and the `.terraform/` working directory.

* **The Fix:** Removed the local Terraform state and cache files and reinitialized the working directory.

```bash
rm -rf .terraform/
rm -f terraform.tfstate terraform.tfstate.backup
```
*Note: Terraform state is authoritative. Changing project IDs in configuration files alone is insufficient if the existing state references another environment.

---

## 3. Environment Variable Overrides

* **The Problem:** After pointing the standard `gcloud` context to the newly generated project, the local terminal window completely ignored the updates. Commands to verify project variables or interact with APIs continuously defaulted back to an invalid environment string: `<OLD_GCP_PROJECT_ID>`.

* **The Cause:** Local shell environments run a strict prioritization scheme. High-priority environment flags (`CLOUDSDK_CORE_PROJECT` and `GOOGLE_PROJECT`) were holding active overrides in the terminal buffer from an early session setup pass. These system overrides consistently hijacked standard configuration modifications behind the scenes.

* **The Fix:** I executed a terminal cache memory clear by unsetting the conflicting environment definitions entirely. I then remaped the environment variables to align exactly with the real project id string: `<YOUR_GCP_PROJECT_ID>`.

Clear any previously exported project environment variables to prevent them from overriding the active Google Cloud configuration.
```bash
unset CLOUDSDK_CORE_PROJECT
unset GOOGLE_PROJECT
```

Set the target Google Cloud project as the active CLI context.
```bash
gcloud config set project <YOUR_GCP_PROJECT_ID>
```

Verify that the active project context updated successfully.
```bash
gcloud config get-value project
```

Expected output:
```text
<YOUR_GCP_PROJECT_ID>
```

---

## 4. GCP Billing and Project Configuration Issues

* **The Problem:** When running a plan compilation or script execution against the unblocked project space, the platform threw a critical security lockout: `googleapi: Error 403: Consumer 'projects/my-project-51160' has been suspended`. 

* **The Cause:** * **The Cause:** Terraform attempted to create network resources that included a public ingress rule (`source_ranges = ["0.0.0.0/0"]`). The GCP project was not fully configured for billing and resource provisioning, causing Google Cloud API requests to fail with a `403` project suspension/permission error. The deployment could not proceed until billing status and project authorization settings were corrected.

* **The Fix:** I bypassed the console interface and used the terminal tool belt to explicitly bind a verified active billing voucher token profile directly into the core project metadata container.

```bash
# Force-linking the payment channel architecture to lift the automated lock
gcloud billing projects link <YOUR_GCP_PROJECT_ID> \
  --billing-account=<BILLING_ACCOUNT_ID>
```

---

## 5. Shell Command Formatting and API Enablement

* **The Problem:** While executing service activation scripts, the command line prompt failed with an `AUTH_PERMISSION_DENIED` and reported a `SERVICE_CONFIG_NOT_FOUND_OR_PERMISSION_DENIED` error. The error details indicated that the command execution target was pointing to a broken website literal string: `://googleapis.com`.

* **The Cause:** A copy-paste formatting line-wrap anomaly occurred within the shell terminal buffer. The line-continuation backslash characters (`\`) were incorrectly parsed, causing the terminal interpreter to split the multi-line input block. The engine attempted to interpret a malformed slice of the script argument as a raw service call destination.

* **The Fix:** * **The Fix:** Linked the active billing account to the GCP project and verified that the project was enabled for resource provisioning.

```bash
# Breaking arguments down to safe, single-line sequential inputs
gcloud services enable compute.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable iamcredentials.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

---

## 6. IAM Permission Propagation and Role Configuration

* **The Problem:** After aligning project contexts, activating the core engines, and establishing financial parameters, running a resource deployment plan failed on the networking phase with an internal permission blocker: `Error creating Firewall: googleapi: Error 403: Permission denied on resource project civic-champion-439320-a5`.

* **The Cause:** When a project is updated or generated on a fresh machine environment, global identity synchronization delays can happen across Google's distributed backend directories. The master account identity (`abbeyster@gmail.com`) had not yet inherited full security authorization mappings across the local Compute Engine networking subclass.

* **The Fix:** I manually injected a high-clearance IAM role binding statement to assign explicit administrative rights over the compute security system directly onto the user profile, then flushed the background token keys.

```bash
# Manual privilege escalation block for security network creation
gcloud projects add-iam-policy-binding <YOUR_GCP_PROJECT_ID> \
    --member="user:<YOUR_GOOGLE_ACCOUNT>" \
    --role="roles/compute.admin"

gcloud auth application-default login
```