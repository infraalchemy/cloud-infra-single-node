resource "google_compute_instance" "cloud_vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.disk_size_gb
    }
  }

  network_interface {
    network = "default"

    access_config {}
  }
  

  metadata_startup_script = <<-EOF
    #!/bin/bash
    exec > /var/log/startup-script.log 2>&1
    sudo apt update
    sudo apt install -y docker-compose
    systemctl enable docker
    systemctl start docker
    sudo usermod -aG docker $USER
  EOF

  tags = ["http-server", "https-server"]
}

# Firewall
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}
