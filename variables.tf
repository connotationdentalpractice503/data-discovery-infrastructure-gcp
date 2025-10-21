variable "project_id" {
  description = "GCP Project ID for GKE cluster and all resources"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "data-discovery-cluster"
}

# Shared VPC Configuration
# For same-project VPC: Set network_project_id = project_id (or leave unset, defaults to project_id)
# For cross-project Shared VPC: Set network_project_id to the host project ID

variable "network_project_id" {
  description = "Project ID where the VPC network resides (host project for Shared VPC). Defaults to project_id if not specified."
  type        = string
  default     = ""
}

variable "network" {
  description = "VPC network for GKE and Composer. Use self-link format: projects/PROJECT_ID/global/networks/NETWORK_NAME or short name 'NETWORK_NAME' (for same project)"
  type        = string

  validation {
    condition     = can(regex("^projects/.+/global/networks/.+$", var.network)) || can(regex("^[a-z][-a-z0-9]*$", var.network))
    error_message = "Network must be either a self-link (projects/PROJECT_ID/global/networks/NETWORK_NAME) or a short name (network-name)."
  }
}

variable "subnetwork" {
  description = "VPC subnetwork for GKE and Composer. Use self-link format: projects/PROJECT_ID/regions/REGION/subnetworks/SUBNET_NAME or short name 'SUBNET_NAME' (for same project)"
  type        = string

  validation {
    condition     = can(regex("^projects/.+/regions/.+/subnetworks/.+$", var.subnetwork)) || can(regex("^[a-z][-a-z0-9]*$", var.subnetwork))
    error_message = "Subnetwork must be either a self-link (projects/PROJECT_ID/regions/REGION/subnetworks/SUBNET_NAME) or a short name (subnet-name)."
  }
}

variable "pods_secondary_range_name" {
  description = "Name of the secondary IP range for GKE pods (must exist in the subnetwork)"
  type        = string
  default     = "podcloud"
}

variable "services_secondary_range_name" {
  description = "Name of the secondary IP range for GKE services (must exist in the subnetwork)"
  type        = string
  default     = "servicecloud"
}

variable "machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "initial_node_count" {
  description = "Initial number of nodes in the node pool"
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 5
}

variable "jsonl_bucket_name" {
  description = "Name of GCS bucket for JSONL files (Vertex AI Search ingestion)"
  type        = string
}

variable "reports_bucket_name" {
  description = "Name of GCS bucket for Markdown reports"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "enable_gke" {
  description = "Enable GKE cluster deployment. Set to false to skip GKE resources."
  type        = bool
  default     = true
}

variable "composer_env_name" {
  description = "Name of the Cloud Composer environment"
  type        = string
  default     = "data-discovery-agent-composer"
}

variable "composer_region" {
  description = "Region for the Cloud Composer environment"
  type        = string
  default     = "us-central1"
}

variable "composer_image_version" {
  description = "Composer image version"
  type        = string
  default     = "composer-3-airflow-2.10.5"
}

# Data Discovery Agent Configuration Variables
variable "vertex_datastore_id" {
  description = "Vertex AI Search datastore ID for document indexing"
  type        = string
}

variable "vertex_location" {
  description = "Vertex AI location (e.g., global, us-central1)"
  type        = string
  default     = "global"
}

variable "bq_dataset" {
  description = "BigQuery dataset for discovered metadata export"
  type        = string
  default     = "data_discovery"
}

variable "bq_table" {
  description = "BigQuery table for discovered metadata export"
  type        = string
  default     = "discovered_assets"
}

variable "bq_location" {
  description = "BigQuery dataset location"
  type        = string
  default     = "US"
}

# Data Lineage Configuration
variable "lineage_enabled" {
  description = "Enable or disable Data Catalog Lineage tracking"
  type        = bool
  default     = true
}

variable "lineage_location" {
  description = "GCP region for Data Catalog Lineage API (should match your main region)"
  type        = string
  default     = "" # Empty string means use var.region
}

# Artifact Registry Configuration
variable "artifact_registry_location" {
  description = "Location for Artifact Registry repository"
  type        = string
  default     = "us-central1"
}

variable "artifact_registry_repository_id" {
  description = "ID of the Artifact Registry repository for Docker images"
  type        = string
  default     = "data-discovery"
}

variable "artifact_registry_retention_days" {
  description = "Number of days to retain untagged images"
  type        = number
  default     = 30
}

variable "artifact_registry_keep_count" {
  description = "Number of most recent image versions to keep"
  type        = number
  default     = 10
}

