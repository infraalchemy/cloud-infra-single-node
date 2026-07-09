# Kubernetes Migration Post-Mortem

Deploying a complex, multi-tier stateful application like Moodle into a local Kubernetes cluster introduced several architectural challenges involving networking, storage, initialization, and application configuration.

## 1. The Ghost Port Blockade & Local Network Conflict (Windows Layer & Cluster Configuration)

* **The Problem:** I encountered a flat refusal to connect on `localhost`. Running a process trace revealed zombie background instances of `com.docker.backend.exe` and `wslrelay.exe` holding host ports 80 and 443. Additionally, my initial Kind cluster configuration exposed secure traffic through host port `443`, which conflicted with the local cluster networking configuration.

* **The Fix:** I cleared stale Docker Desktop and WSL2 networking state using `Stop-Process` and `wsl --shutdown`. I then recreated the Kind cluster with updated port mappings, moving secure web traffic to host port `8443` while keeping the Kubernetes cluster networking isolated.

```yaml
hostPort: 80          # HTTP traffic
hostPort: 8443        # HTTPS traffic moved away from host port 443
```

---

## 2. Ingress Traffic Redirection Loops (Ingress Rules Layer)

* **The Problem:** Even with ports unblocked, local browser traffic was being redirected into SSL/TLS loops, preventing successful HTTP-based application testing.

* **The Fix:** I disabled the Nginx Ingress controller's automatic SSL redirect behavior by adding annotations to `ingress.yaml`, allowing local HTTP traffic to reach the application without forced HTTPS redirection.

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
```

---

## 3. FastCGI Connection Timeout Drops (Nginx Configuration Tier)

* **The Problem:** During the Moodle installation database population phase, backend PHP execution exceeded the default Nginx timeout thresholds. The reverse proxy terminated long-running requests before database initialization completed.

* **The Fix:** I modified the Nginx server block configuration to increase FastCGI timeout values, allowing long-running Moodle installation and database migration tasks to complete successfully.

```nginx
fastcgi_read_timeout 600s;
fastcgi_send_timeout 600s;
```

---

## 4. The Isolated Container Network Lock (PHP-FPM Topology)

* **The Problem:** Inbound web traffic successfully reached the Nginx frontend but failed when forwarding requests to PHP-FPM. Investigation showed the PHP image defaulted to a local-only listener (`listen = 127.0.0.1:9000`), preventing communication from the separate Nginx container running in another Kubernetes pod.

* **The Fix:** I tested patching the PHP-FPM listener through Kubernetes runtime commands. This approach replaced the container's native startup behavior and affected the image lifecycle. I then moved the configuration change into the Docker build process by adding a `sed` instruction directly into the `Dockerfile` to configure PHP-FPM to listen on `9000`.

---

## 5. The HTML Web Page Download Trap (Init Container Storage Pipeline)

* **The Problem:** The Moodle PHP pod became stuck in an `Init:Error` state. Reviewing the initialization container logs showed that the download process retrieved HTML page content instead of the Moodle application archive, causing the extraction process (`tar`) to fail.

* **The Fix:** I updated the `initContainers` configuration in `deployment.yaml` with a direct Moodle archive URL and corrected command parameters. I then removed the corrupted Persistent Volume Claim (`moodle-pvc`) so the initialization process could start with clean storage.

---

## 6. The Application Resource Deprivation Barrier (Application Optimization)

* **The Problem:** Inspection of the PHP runtime configuration showed the default container memory allocation was limited to `128M`. Moodle requires additional resources during initial installation to process directory indexing and database table creation.

* **The Fix:** I added a custom PHP configuration override (`moodle.ini`) during the Docker image build process to increase the runtime limits:

```ini
memory_limit=512M
max_execution_time=300
```

---

## 7. The Hidden Worker Node Redirection (Ingress Routing Scheduling)

* **The Problem:** Every application pod reported healthy, yet browser requests still returned `ERR_EMPTY_RESPONSE`. Investigation showed that Kubernetes had automatically scheduled the `ingress-nginx-controller` pod onto the `lab-worker` node. Unlike a managed cloud Kubernetes environment, my local Kind cluster runs inside Docker containers, and Windows host port mappings were attached only to the `lab-control-plane` node. External traffic entered through the control-plane node, but the ingress controller was running on the worker node, creating a dead-end routing path.

* **The Fix:** I applied a `kubectl patch` with a strict `nodeSelector` configuration, forcing the `ingress-nginx-controller` pod to run on the `lab-control-plane` node where the Windows host port mappings were connected. This aligned the local network entry point with the Kubernetes ingress routing layer.