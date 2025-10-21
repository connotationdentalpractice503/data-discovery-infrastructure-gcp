# Data Discovery Agent - Main Infrastructure Configuration
# Phase 0: GKE Cluster, GCS Buckets, and Service Accounts

# ------------------------------------------------------------------------------
# Shared VPC Configuration
# ------------------------------------------------------------------------------
# This infrastructure supports both same-project and cross-project Shared VPC:
#
# Same-Project VPC:
#   - Leave network_project_id unset (or set to project_id)
#   - Use short network names or self-links
#
# Cross-Project Shared VPC:
#   - Set network_project_id to the host project ID
#   - Use full self-link format for network and subnetwork
#   - Ensure host project has granted service account permissions
#
# Prerequisites for Shared VPC:
#   1. Subnet must have secondary IP ranges configured:
#      - pods_secondary_range_name (default: "podcloud")
#      - services_secondary_range_name (default: "servicecloud")
#   2. For cross-project Shared VPC, service accounts need roles/compute.networkUser
#      in the host project (configured below)
#   3. Google-managed service accounts need network permissions (configured below)
# ------------------------------------------------------------------------------

locals {
  # Default network_project_id to project_id if not specified
  network_project_id = var.network_project_id != "" ? var.network_project_id : var.project_id
  
  # Determine if this is a cross-project Shared VPC setup
  is_shared_vpc = local.network_project_id != var.project_id
  
  # Construct subnet resource name for IAM bindings
  # Format: projects/{project}/regions/{region}/subnetworks/{name}
  subnet_resource = can(regex("^projects/.+/regions/.+/subnetworks/.+$", var.subnetwork)) ? var.subnetwork : "projects/${local.network_project_id}/regions/${var.region}/subnetworks/${var.subnetwork}"
}

# Enable required GCP APIs
resource "google_project_service" "required_apis" {
  for_each = toset(concat(
    [
      "storage.googleapis.com",        # Cloud Storage
      "iam.googleapis.com",            # IAM
      "secretmanager.googleapis.com",  # Secret Manager
      "cloudscheduler.googleapis.com", # Cloud Scheduler
      "bigquery.googleapis.com",       # BigQuery
      "datacatalog.googleapis.com",    # Data Catalog
      "logging.googleapis.com",        # Cloud Logging
      "monitoring.googleapis.com",     # Cloud Monitoring
      "dlp.googleapis.com",            # DLP
      "aiplatform.googleapis.com",     # Vertex AI
      "compute.googleapis.com",        # Compute (for networking)
      "dataplex.googleapis.com",       # Dataplex (for lineage and data quality)
      "composer.googleapis.com",       # Cloud Composer
      "artifactregistry.googleapis.com", # Artifact Registry
    ],
    var.enable_gke ? ["container.googleapis.com"] : [] # GKE (optional)
  ))

  project = var.project_id
  service = each.key

  disable_on_destroy = false
}

# GKE Cluster with Workload Identity and Private Nodes
resource "google_container_cluster" "data_discovery" {
  count    = var.enable_gke ? 1 : 0
  name     = var.cluster_name
  location = var.region

  # Use regional cluster for high availability
  # Standard mode (not Autopilot) for custom machine types

  # Network configuration - using existing VPC and subnet
  network    = var.network
  subnetwork = var.subnetwork

  # Remove default node pool immediately (we'll create a custom one)
  remove_default_node_pool = true
  initial_node_count       = 1

  # Temporarily disable deletion protection to allow cluster recreation
  deletion_protection = false

  # Workload Identity configuration (required for GKE → GCP service account binding)
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Private cluster configuration - no external IPs for nodes
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false           # Keep master endpoint public for easier management
    master_ipv4_cidr_block  = "172.21.0.0/28" # Private IP range for master (changed to avoid conflicts)
  }

  # IP allocation for pods and services
  # Using existing secondary ranges from the VPC subnet
  # These ranges must exist in the subnet before deploying GKE
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  # Master authorized networks - restrict access to cluster master
  # Add your IP ranges here for additional security
  master_authorized_networks_config {
    # Allow access from everywhere for now (adjust for production)
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All networks"
    }
  }

  # Enable basic security features
  enable_shielded_nodes = true

  # Resource labels
  resource_labels = {
    environment = var.environment
    managed_by  = "terraform"
    component   = "data-discovery"
  }

  # Maintenance window (optional - adjust as needed)
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00" # 3 AM maintenance window
    }
  }

  depends_on = [
    google_project_service.required_apis
  ]
}

# Custom node pool with e2-standard-2 instances
resource "google_container_node_pool" "primary_nodes" {
  count    = var.enable_gke ? 1 : 0
  name     = "${var.cluster_name}-node-pool"
  location = var.region
  cluster  = google_container_cluster.data_discovery[0].name

  initial_node_count = var.initial_node_count

  # Autoscaling configuration
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  # Node configuration
  node_config {
    machine_type = var.machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard"

    # Use custom service account with minimal permissions
    service_account = google_service_account.gke_sa[0].email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Security: Enable shielded nodes
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Labels
    labels = {
      environment = var.environment
      component   = "data-discovery"
    }

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Tags for firewall rules (if needed)
    tags = ["data-discovery", var.environment]
  }

  # Node management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  depends_on = [
    google_container_cluster.data_discovery
  ]
}

# ------------------------------------------------------------------------------
# Shared VPC IAM Bindings
# ------------------------------------------------------------------------------
# Grant compute.networkUser role to service accounts on the subnet
# This is required for cross-project Shared VPC configurations
# For same-project VPC, these bindings are created but not strictly necessary
# ------------------------------------------------------------------------------

# GKE Service Account - needs network user permission for node creation
resource "google_compute_subnetwork_iam_member" "gke_sa_network_user" {
  count      = var.enable_gke ? 1 : 0
  project    = local.network_project_id
  region     = var.region
  subnetwork = var.subnetwork
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${google_service_account.gke_sa[0].email}"

  depends_on = [
    google_service_account.gke_sa
  ]
}

# Google-managed GKE Service Account - needs network user permission
# Format: service-{PROJECT_NUMBER}@container-engine-robot.iam.gserviceaccount.com
data "google_project" "service_project" {
  project_id = var.project_id
}

resource "google_compute_subnetwork_iam_member" "gke_api_network_user" {
  count      = var.enable_gke ? 1 : 0
  project    = local.network_project_id
  region     = var.region
  subnetwork = var.subnetwork
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${data.google_project.service_project.number}@container-engine-robot.iam.gserviceaccount.com"

  depends_on = [
    google_project_service.required_apis
  ]
}

# Composer Service Account - needs network user permission for worker VMs
resource "google_compute_subnetwork_iam_member" "composer_sa_network_user" {
  project    = local.network_project_id
  region     = var.region
  subnetwork = var.subnetwork
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${google_service_account.composer_sa.email}"

  depends_on = [
    google_service_account.composer_sa
  ]
}

# Google-managed Composer Service Account - needs network user permission
# Format: service-{PROJECT_NUMBER}@cloudcomposer-accounts.iam.gserviceaccount.com
resource "google_compute_subnetwork_iam_member" "composer_api_network_user" {
  project    = local.network_project_id
  region     = var.region
  subnetwork = var.subnetwork
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${data.google_project.service_project.number}@cloudcomposer-accounts.iam.gserviceaccount.com"

  depends_on = [
    google_project_service.required_apis
  ]
}

