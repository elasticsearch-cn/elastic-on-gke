variable "zone" {
  description = "zone"
}

variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "elastic_cluster_name" {
  default = "elk"
  description = "GKE cluster name"
}

variable "elastic_primary_es_node_pool" {
  default = "elasticsearch"
  description = "the primary node/resource pool for Elasticsearch nodes"
}

variable "elastic_kbn_node_pool" {
  default = "kibana"
  description = "the node/resource pool for Kibana"
}

variable "gke_min_master_ver" {
  description = "The minimum version of the master"
}

variable "gke_node_ver" {
  description = "The Kubernetes version on the nodes"
}

variable "gke_num_nodes" {
  default     = 4
  description = "number of gke nodes"
}

# GKE cluster
resource "google_container_cluster" "primary" {
  name     = var.elastic_cluster_name
  #location   = var.region
  location = "${var.region}-${var.zone}"
  #node_locations = [
  #  "${var.region}-${var.zone}",
  #]

  release_channel {
    channel = "STABLE"
  }
  min_master_version = var.gke_min_master_ver
  #node_version = var.gke_node_ver
  
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  #master_auth {
  #  username = var.gke_username
  #  password = var.gke_password

  #  client_certificate_config {
  #    issue_client_certificate = false
  #  }
  #}
}

# Separately Managed Node Pool - Elasticsearch
resource "google_container_node_pool" "primary_elasticsearch_nodes" {
  name       = var.elastic_primary_es_node_pool
  #location   = var.region
  location = "${var.region}-${var.zone}"
  #node_locations = [
  #  "${var.region}-${var.zone}",
  #]
  version = var.gke_node_ver
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = "elasticsearch-gke"
    }

    # preemptible  = true
    machine_type = "e2-standard-4" # 4C16GB
    tags         = ["gke-es-node",]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge = 1
    max_unavailable = 0
  }
}

# Separately Managed Node Pool - Kibana
resource "google_container_node_pool" "kibana_nodes" {
  name       = var.elastic_kbn_node_pool
  location = "${var.region}-${var.zone}"
  #node_locations = [
  #  "${var.region}-${var.zone}",
  #]
  version = var.gke_node_ver
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = "kibana-gke"
    }

    # preemptible  = true
    machine_type = "e2-standard-2" # 2C8GB
    tags         = ["gke-kbn-node",]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair = true
    auto_upgrade = true
  }
}

# # Kubernetes provider
# # The Terraform Kubernetes Provider configuration below is used as a learning reference only. 
# # It references the variables and resources provisioned in this file. 
# # We recommend you put this in another file -- so you can have a more modular configuration.
# # https://learn.hashicorp.com/terraform/kubernetes/provision-gke-cluster#optional-configure-terraform-kubernetes-provider
# # To learn how to schedule deployments and services using the provider, go here: https://learn.hashicorp.com/tutorials/terraform/kubernetes-provider.

# provider "kubernetes" {
#   load_config_file = "false"

#   host     = google_container_cluster.primary.endpoint
#   username = var.gke_username
#   password = var.gke_password

#   client_certificate     = google_container_cluster.primary.master_auth.0.client_certificate
#   client_key             = google_container_cluster.primary.master_auth.0.client_key
#   cluster_ca_certificate = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
# }