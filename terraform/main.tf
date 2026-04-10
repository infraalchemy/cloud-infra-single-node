
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

    access_config {
      # Ephemeral public IP
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y docker.io docker-compose-plugin git
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu
  EOF

  tags = ["http-server", "https-server"]
}

