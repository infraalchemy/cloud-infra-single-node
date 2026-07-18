# Infrastructure Migration Post-Mortem

Deploying the infrastructure architecture onto Google Cloud Platform (GCP) from a fresh system account profile introduced several systemic challenges involving authorization states, platform security boundaries, shell context variables, and syntax truncation rules.

---

## 1. The Legacy State Memory & Project Identity Collision (Terraform Caching Layer)

* **The Problem:** I encountered an immediate `403 Forbidden` error when trying to run `terraform plan`. The local command engine flatly refused to validate the blueprint. The system error message tracked an old, legacy project environment name (`cloud-lab-492115`) which was nowhere to be found in the current source code configuration files.

* **The Cause:** Even though the project ID was removed from the active `.tf` code blocks, Terraform had cached the exact resource metadata and tracking mappings from the previous computer session directly inside its local `.tfstate` and `.terraform/` history directories. When executed, Terraform attempted to inspect the ghost resources in the old project, triggering a permission denial.

* **The Fix:** I completely purged the hidden configuration cache directories and legacy tracking files using `rm -rf`. This forced the infrastructure mapping manager back into an absolute clean-slate state.

```bash
# Wiping the state database to break tracking ties with the old account
rm -rf .terraform/
rm -f terraform.tfstate terraform.tfstate.backup
```

---

## 2. The Terminal Environment Tug-of-War (Local CLI Variable Mappings)

* **The Problem:** After pointing the standard `gcloud` context to the newly generated project, the local terminal window completely ignored the updates. Commands to verify project variables or interact with APIs continuously defaulted back to an invalid environment string: `my-project-51160`.

* **The Cause:** Local shell environments run a strict prioritization scheme. High-priority environment flags (`CLOUDSDK_CORE_PROJECT` and `GOOGLE_PROJECT`) were holding active overrides in the terminal buffer from an early session setup pass. These system overrides consistently hijacked standard configuration modifications behind the scenes.

* **The Fix:** I executed a terminal cache memory clear by unsetting the conflicting environment definitions entirely. I then remaped the environment variables to align exactly with the real project id string: `civic-champion-439320-a5`.

```bash
# Force-clearing the terminal priority buffer memories
unset CLOUDSDK_CORE_PROJECT
unset GOOGLE_PROJECT

export GOOGLE_PROJECT="civic-champion-439320-a5"
export CLOUDSDK_CORE_PROJECT="civic-champion-439320-a5"
```

---

## 3. The Empty-Financial Security Blockade (GCP Threat Mitigation Layer)

* **The Problem:** When running a plan compilation or script execution against the unblocked project space, the platform threw a critical security lockout: `googleapi: Error 403: Consumer 'projects/my-project-51160' has been suspended`. 

* **The Cause:** When Terraform executes, the network configuration blocks request an open ingress rule targeting the whole public world (`source_ranges = ["0.0.0.0/0"]`). To GCP's automated threat-detection mechanisms, opening global web communication ports on a fresh user account that has no valid financial billing backing linked to it mimics a security compromise. The system applied an automatic, preventive suspension block to safeguard platform resources.

* **The Fix:** I bypassed the console interface and used the terminal tool belt to explicitly bind a verified active billing voucher token profile directly into the core project metadata container.

```bash
# Force-linking the payment channel architecture to lift the automated lock
gcloud billing projects link civic-champion-439320-a5 \
  --billing-account=01A435-5FF40E-9232BA
```

---

## 4. The Multi-Line Input Parsing Truncation (Shell Execution Syntax)

* **The Problem:** While executing service activation scripts, the command line prompt failed with an `AUTH_PERMISSION_DENIED` and reported a `SERVICE_CONFIG_NOT_FOUND_OR_PERMISSION_DENIED` error. The error details indicated that the command execution target was pointing to a broken website literal string: `://googleapis.com`.

* **The Cause:** A copy-paste formatting line-wrap anomaly occurred within the shell terminal buffer. The line-continuation backslash characters (`\`) were incorrectly parsed, causing the terminal interpreter to split the multi-line input block. The engine attempted to interpret a malformed slice of the script argument as a raw service call destination.

* **The Fix:** I isolated the execution parameters, dropping the multi-line array mappings down into separate, independent execution passes.

```bash
# Breaking arguments down to safe, single-line sequential inputs
gcloud services enable googleapis.com
gcloud services enable googleapis.com
gcloud services enable googleapis.com
```

---

## 5. The Sync Latency Access Lockout (IAM Propagation Delay)

* **The Problem:** After aligning project contexts, activating the core engines, and establishing financial parameters, running a resource deployment plan failed on the networking phase with an internal permission blocker: `Error creating Firewall: googleapi: Error 403: Permission denied on resource project civic-champion-439320-a5`.

* **The Cause:** When a project is updated or generated on a fresh machine environment, global identity synchronization delays can happen across Google's distributed backend directories. The master account identity (`abbeyster@gmail.com`) had not yet inherited full security authorization mappings across the local Compute Engine networking subclass.

* **The Fix:** I manually injected a high-clearance IAM role binding statement to assign explicit administrative rights over the compute security system directly onto the user profile, then flushed the background token keys.

```bash
# Manual privilege escalation block for security network creation
gcloud projects add-iam-policy-binding civic-champion-439320-a5 \
    --member="user:abbeyster@gmail.com" \
    --role="roles/compute.admin"

gcloud auth application-default login
```

# Technical Addendum: Web Interface Installation & CLI Workload Recovery

This section documents the hybrid engineering process used to execute the Moodle database setup via the web installation wizard, bypass the administrative session profile timeout error via the container command line, and programmatically validate data persistence.

---

# 1. Hybrid Web Wizard Installation Execution

### Operational Sequence
To maximize deployment velocity, the environment initialization was completed using a coordinated hybrid sequence. The relational database schema, tables, and engine configurations were built using the visual user interface up until the final boundary block:

1. Navigated to the cloud VM external IP address string via an Incognito browser window: `http://34.130.98.92`
2. Followed the guided web installation screens to link the Nginx proxy, PHP runtime, and MySQL relational database.
3. Allowed the engine to execute the complete compilation loop, outputting a rolling page of green **"Success"** database table initialization logs.
4. Selected the blue **"Continue"** confirmation action button at the base of the table compilation summary screen.
5. Arrived exactly at the final system-generated administrative user configuration page target path:
   ```text
   http://34.130.98
   ```

---

# 2. Reverse Proxy Session Drop Lifecycle (The Invalid Sesskey Bug)

### Cause
The exact millisecond the web setup wizard redirected traffic onto the final profile step (`/user/editadvanced.php?id=2`), the platform threw an automated intercept block when attempting to update user metadata fields. 

Because the web installer compiles data inside an isolated Docker container bridge network space, it generates form verification keys based on local network parameters. When an external web browser pushes form modifications from the outside world across a raw, ephemeral cloud IP address, Moodle detects a cross-domain token mismatch. It flags the operation as a security threat and terminates the tracking handshake, outputting:

```text
error/moodle/invalidsesskey
The most likely reason for obtaining an "Invalid Sesskey" message is because your session has timed out.
```

### Resolution
Left the web browser window open on the stuck form page to preserve the compiled installer state. Jumped directly into the VM host browser SSH console and executed Moodle's built-in administration command-line interface (CLI) utilities inside the running `php-fpm` container layer. 

This bypassed the broken web screen entirely, force-seeding the administrator account details and password properties directly into the MySQL database tables from the terminal:

```bash
# 1. Force update the master administrator password via terminal injection
docker exec -it docker_php-fpm_1 php /var/www/html/admin/cli/reset_password.php --username=admin

# 2. Flush the broken security tokens out of the session backend cache
docker exec -it docker_php-fpm_1 php /var/www/html/admin/cli/purge_caches.php
```

---

# 3. Reverse Proxy Infinite Redirection Loop (`ERR_TOO_MANY_REDIRECTS`)

### Cause
Immediately following the terminal administration profile update, browser requests navigating back to the login landing page triggered a continuous circular path routing error. This occurs because the internal `config.php` file lacks explicit instructions defining its relationship with the external gateway proxy layer. Nginx forwards data down to PHP-FPM, and PHP-FPM bounces it back to Nginx, trapping user connections.

### Resolution
Hard-aligned reverse proxy mapping constraints directly on the VM host's underlying storage volume block without altering the local repository files. Injected compliance flags directly into the configuration array using string modification utilities:

```bash
# Force-inject reverse proxy trust settings directly into the active config file layout
sudo sed -i "/require_once/i \$CFG->reverseproxy = true;\n\$CFG->sslproxy = false;\n" /var/lib/docker/volumes/docker_moodle_code/_data/config.php

# Cycle the application stack to load the newly updated configuration properties
docker-compose restart
```

---

# 4. Moodle Web Layout Render Failures (Broken Interface Navigation)

### Cause
Due to asset rendering conflicts between Moodle's "slash arguments" property and standard Nginx location parsing configurations, the web page loaded raw HTML without functional CSS styling or working hyperlink routes. Clicking buttons via the browser interface to complete the storage persistence test was unavailable.

### Resolution
Bypassed browser operations entirely. Executed all Phase 4 high-availability storage verification and lifecycle validation checks programmatically via the virtual machine command line interface.

```bash
# 1. Programmatically inject the validation test course into the database
docker exec -it docker_php-fpm_1 php /var/www/html/admin/cli/create_course.php \
  --fullname="Infrastructure Test Course" \
  --shortname="PersistenceTest" \
  --category=1

# 2. Construct the direct persistence tracking file marker in the shared app volume
docker exec -it docker_php-fpm_1 bash -c \
  "echo 'Docker Compose persistence validation test' > /var/www/moodledata/persistence-test.txt"

# 3. Verify that the file can be read through the container runtime layers
docker exec -it docker_php-fpm_1 cat /var/www/moodledata/persistence-test.txt

# 4. Audit course entry metric count inside the relational storage engine before destruction
docker exec -it docker-mysql-1 mysql -u moodleuser -p'yourpassword' \
  -e "USE moodle; SELECT COUNT(*) FROM mdl_course;"
```

---

# 5. Complete Container Destruction & Recovery Loop

To verify that the application layer is successfully separated from the data persistence layer, execute a full runtime service rotation flight:

```bash
# Tear down active runtime containers and networks while protecting named storage volumes
docker-compose down

# Verify zero application components remain online on the VM host
docker ps -a

# Relaunch the infrastructure stack cleanly
docker-compose up -d
```

### Final Data Consistency Audit
Verify the tracking file and database transactions completely survived the infrastructure container rotation:

```bash
# Expected output: "Docker Compose persistence validation test"
docker exec -it docker_php-fpm_1 cat /var/www/moodledata/persistence-test.txt

# Expected output: Course count matches the initial metrics baseline exactly
docker exec -it docker-mysql-1 mysql -u moodleuser -p'yourpassword' \
  -e "USE moodle; SELECT COUNT(*) FROM mdl_course;"
```

**Result:** Data persistence verified. The multi-container workload safely handles container lifecycle destruction loops with zero application state loss.

