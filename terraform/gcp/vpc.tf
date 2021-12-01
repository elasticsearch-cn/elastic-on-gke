variable "project_id" {
  description = "project id"
}

variable "region" {
  description = "region"
}

variable "elastic_vpc" {
  description = "vpc name dedicated for Elastic Stack on GKE"
}

variable "elastic_subnet" {
  description = "subnet dedicated for Elastic Stack on GKE"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC
resource "google_compute_network" "vpc" {
  # name                    = "${var.project_id}-vpc"
  name                    = "${var.elastic_vpc}"
  auto_create_subnetworks = "false"
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  #name          = "${var.project_id}-subnet"
  name          = "${var.elastic_subnet}"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.10.0.0/24"
}
