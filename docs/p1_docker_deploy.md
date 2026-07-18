# Phase 1 Deployment Runbook: docker-compose Workload & Persistence Validation

This guide documents the deployment, configuration, validation, and persistence testing of a containerized Moodle environment using docker-compose on a Google Cloud Compute Engine virtual machine.

---

# Prerequisites

This workload assumes a clean Linux Compute Engine VM has been successfully provisioned.

Required software on the host VM:

- Docker Engine
- docker-compose V2 (space syntax: `docker-compose`)
- Git

Verify installations:
```bash
docker --version
docker-compose version
git --version
```

---

# Deployment Workflow

The workload deployment follows this sequence:

1. Configure Docker runtime permissions
2. Clone infrastructure repository and prepare environment configuration
3. Build custom application container images
4. Launch isolated application services
5. Validate container health and internal networking
6. Complete Moodle web installation wizard configuration
7. Verify database initialization
8. Execute container lifecycle persistence validation
9. Stop and optionally destroy workload resources

---

## Connect to the Host Virtual Machine

Connect directly to your running cloud instance using the browser console interface (Easiest):
1. Open your web browser to the **GCP Compute Engine Console**.
2. Click the blue **SSH** button link on the far right of your VM's row.

Alternatively, connect directly via your local terminal command line:
```bash
gcloud compute ssh <YOUR_VM_NAME> --zone=<YOUR_VM_ZONE>
```

---

## Configure Docker Permissions

Enable Docker and configure the local user for non-root Docker execution:
```bash
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
```

Verify Docker commands execute without elevated privileges:
```bash
docker ps
```

Expected result:
```text
CONTAINER ID   IMAGE   COMMAND   CREATED   STATUS   PORTS   NAMES
```

---

## Application Deployment


Clone the project repository:
```bash
git clone <your-repository-url>
cd cloud-infra-single-node/docker
```

Verify the Docker deployment structure:
```bash
ls -la
```

Expected:
```text
docker-compose.yml
nginx/
php/
mysql/
```

---

## Configure Environment Variables

The `.env` file contains database credentials and sensitive configuration values. It is excluded from source control through `.gitignore`.

The '.env' file must be created in the same directory as 'docker-compose.yml'.
```bash
nano .env
```

Populate the required variables:
```text
MYSQL_ROOT_PASSWORD=your_secure_root_password
MYSQL_DATABASE=moodle
MYSQL_USER=moodleuser
MYSQL_PASSWORD=your_secure_moodle_password
```

Validate that docker-compose successfully resolves the environment configuration:
```bash
docker-compose config
```

*Note: The generated configuration should display resolved service definitions without missing variables.*

---

## Build Application Images

Build the custom application images:
```bash
docker-compose build --no-cache
```

Expected output:
```text
Creating docker_mysql_1   ... done
Creating docker_php-fpm_1 ... done
Creating docker_nginx_1   ... done
```

Start the application stack in detached mode:
```bash
docker-compose up -d
```

Expected deployment output:

```text
[+] Running 5/5
 ✔ Network docker_web_network Created
 ✔ Volume docker_moodle_code Created
 ✔ Container docker-php-fpm-1 Started
 ✔ Container docker-mysql-1 Started
 ✔ Container docker-nginx-1 Started
```
---

# Runtime Verification

Verify the application containers are running
```bash
docker ps
```

Expected services:
```text
docker-nginx-1
docker-php-fpm-1
docker-mysql-1
```
Verify the container networking layer:
```bash
docker network inspect docker_web_network
```

*Note: Confirm that the containers are connected to the expected application network and can communicate through Docker service discovery.*

---

## HTTP Endpoint Verification

Validate that the Nginx reverse proxy is responding locally from the VM:
```bash
curl -I http://localhost
```

Expected response:
```text
HTTP/1.1 302 Found
```

Retrieve the external VM address for browser access:
```bash
curl -4 ifconfig.me
```

Verify that a Google Cloud firewall rule allows inbound HTTP (TCP port 80) to thetarget VM instance.
- **TCP Port:** `80`
- **Source:** Required client access range
- **Target:** VM instance

Open the Moodle deployment:

```text
http://<YOUR_VM_EXTERNAL_IP>
```

---

# Moodle Web Installation

Complete the Moodle installation wizard using the following configuration:

| Setting | Value |
| :--- | :--- |
| **Web Address** | `http://<YOUR_VM_EXTERNAL_IP>` |
| **Moodle Directory** | `/var/www/html` |
| **Moodle Data Directory** | `/var/www/moodledata` |
| **Database Type** | `MySQL` |
| **Database Host** | `mysql` |
| **Database Port** | `3306` |
| **Database Name** | `moodle` |
| **Database User** | `<MYSQL_USER from .env>` |
| **Database Password** | `<MYSQL_PASSWORD from .env>` |
| **Table Prefix** | `mdl_` |

*Notes:*
- *Retain the default Moodle database table prefix (`mdl_`) unless a custom schema strategy is intentionally required.*
- *The database host value must reference the docker-compose service name (`mysql`) rather than `localhost` because the database runs as an independent container.*

---


## Storage Validation

Verify that Moodle application files are available inside the PHP-FPM container:
```bash
docker exec <php container name> ls /var/www/html
```

Verify that Nginx has access to the same shared application volume:
```bash
docker exec <nginx container name> ls /var/www/html
```

Validate write permissions within the Moodle persistent data directory:
```bash
docker exec docker-php-fpm-1 touch /var/www/moodledata/write_test.txt
```

*Note: Successful completion confirms that the PHP runtime can write to persistent application storage.*

---

## Database Verification

Connect to the MySQL container:
```bash
docker exec -it <mysql container name> mysql -u root -p
```

Verify database creation:
```sql
SHOW DATABASES;
```

Expected output:
```text
moodle
```

Verify configured database users:
```sql
SELECT user, host FROM mysql.user;
```

Expected output:
```text
moodleuser %
root %
```

Exit MySQL:
```sql
exit;
```
---

## Persistence Validation

This validation confirms that application data and database state survive container destruction and recreation cycles.

The test demonstrates:
- Persistent Docker volume configuration
- Database storage retention
- Application file persistence
- Container replacement recovery

---

# Create Test Data

Create application test data before container recreation:

1. Log into the Moodle web interface as the administrator.
2. Create a course named:
   ```text
   Infrastructure Test Course
   ```
3. Open the course.
4. Enable editing:
   - Navigate to the **Course page**
   - Select **Turn editing on**
5. Add a file resource:
   - Select **Add an activity or resource**
   - Choose **File**
6. Create a test file on your local computer named:
   `persistence-test.txt`

   Example contents:
   ```text
   docker-compose persistence validation test
   ```
7. Upload `persistence-test.txt` to the Moodle course File resource.

Moodle automatically maps and stores the uploaded file inside the persistent Moodle data directory:
```text
/var/www/moodledata
```
   
Alternatively, create a direct persistence marker inside the Moodle data volume via the command line:
```bash
docker exec docker-php-fpm-1 bash -c "echo 'Persistence Token Verification' > /var/www/moodledata/persistence_lock.txt"
```

Verify that the database contains existing application records before container recreation:
```bash
docker exec -it docker-mysql-1 mysql -u moodleuser -p -e "USE moodle; SELECT COUNT(*) FROM mdl_user;"
```

*Note: Record the returned user count for comparison after recovery.*

---

## Stop Containers

Stop and remove the running application containers:
```bash
docker-compose down
```

*Note: `docker-compose down` removes containers and networks but preserves named Docker volumes. Persistent application and database storage should remain available.*

Verify that application containers no longer exist:
```bash
docker ps -a
```

Expected result:
```text
No active Moodle application containers
```

---

## Start Containers

Recreate the application stack:
```bash
docker-compose up -d
```

Verify that new container instances are running cleanly:
```bash
docker ps
```

Expected services:
```text
docker-nginx-1
docker-php-fpm-1
docker-mysql-1
```

*Note: The container IDs and creation timestamps should be different from the original deployment, confirming full container replacement.*

---

## Verify Persistent Data

Verify the persistence marker survived container recreation:
```bash
docker exec docker-php-fpm-1 cat /var/www/moodledata/persistence_lock.txt
```

Expected output:
```text
Persistence Token Verification
```

Verify that the MySQL database volume retained application records:
```bash
docker exec -it docker-mysql-1 mysql -u moodleuser -p -e "USE moodle; SELECT COUNT(*) FROM mdl_user;"
```

Expected result:
```text
The returned user count matches the value recorded before container recreation.
```
---

## Application Recovery Validation

Confirm the application is still accessible
Open the Moodle site in your web browser:
```text
http://<YOUR_VM_EXTERNAL_IP>
```

Expected results:
- Moodle login page loads successfully.
- Administrator credentials continue to function.
- Previously created courses remain available.
- Uploaded files remain accessible.

Successful completion confirms that the docker-compose deployment correctly separates:
- Container lifecycle
- Application runtime
- Persistent storage
- Database state

*Note: The workload can be safely recreated without any loss of application data.*

---

## Stop and Purge the docker-compose Deployment

Remove the application containers, project network, named volumes, and Docker images associated with this docker-compose deployment:

```bash
docker-compose down -v --rmi all
```

Expected Results:
```text
Stopping docker_nginx_1   ... done
Stopping docker_mysql_1   ... done
Stopping docker_php-fpm_1 ... done
Removing docker_nginx_1   ... done
Removing docker_mysql_1   ... done
Removing docker_php-fpm_1 ... done
Removing network docker_web_network
Removing volume docker_mysql_data
Removing volume docker_moodledata
Removing volume docker_moodle_code
Removing image docker_php-fpm
Removing image docker_nginx
Removing image mysql:8.0
```

*Note:* The `-v` flag removes the named volumes created by this docker-compose project, permanently deleting the Moodle database and all persistent application data. The `--rmi all` option removes the images used by the deployment, ensuring the next deployment performs a complete image rebuild from the Dockerfiles.
