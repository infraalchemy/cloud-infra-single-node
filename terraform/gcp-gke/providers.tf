terraform {
  backend "gcs" {
    bucket = "civic-champion-439320-a5-terraform-state"
    prefix = "gke"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
