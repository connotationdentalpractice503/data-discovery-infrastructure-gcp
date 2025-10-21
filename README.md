# Data Discovery Infrastructure - Google Cloud Platform

![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=flat&logo=terraform&logoColor=white)
![GCP](https://img.shields.io/badge/Google_Cloud-%234285F4.svg?style=flat&logo=google-cloud&logoColor=white)
![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)

A production-ready Terraform infrastructure template for deploying data discovery systems on Google Cloud Platform. This repository provides a complete, reusable infrastructure setup for building data catalog and metadata discovery solutions.

## Overview

This Terraform configuration deploys a comprehensive data discovery infrastructure on GCP, including:

- **GKE Cluster** (optional): Standard mode cluster with Workload Identity and private nodes
- **Cloud Composer**: Managed Apache Airflow for orchestrating data discovery workflows
- **GCS Buckets**: Storage for JSONL files (Vertex AI Search) and Markdown reports
- **Service Accounts**: Least-privilege accounts with appropriate IAM roles
- **Artifact Registry**: Docker image repository for container workloads
- **Monitoring & Logging**: Cloud Monitoring dashboards and log sinks
- **Dataplex Profiling**: Automated data quality and profiling scans (optional module)
- **Vertex AI Search**: Infrastructure for semantic search over metadata (optional module)

## Features

- ✅ **Production-Ready**: Security best practices, private networking, workload identity
- ✅ **Modular Design**: Enable/disable GKE, use subdirectories for optional features
- ✅ **Cost-Optimized**: Autoscaling, lifecycle policies, configurable resource sizes
- ✅ **Fully Parameterized**: No hardcoded values, all configuration via variables
- ✅ **Read-Only by Design**: Discovery service accounts cannot modify source data
- ✅ **Well Documented**: Comprehensive README, quickstart guide, and inline comments

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GCP Project                              │
│                                                              │
│  ┌──────────────┐      ┌─────────────────┐                 │
│  │ Cloud        │      │ GKE Cluster     │ (optional)      │
│  │ Composer     │      │ - Workload ID   │                 │
│  │ (Airflow)    │      │ - Private Nodes │                 │
│  └──────┬───────┘      └────────┬────────┘                 │
│         │                       │                           │
│         │    ┌──────────────────┴─────────────┐            │
│         │    │                                 │            │
│  ┌──────▼────▼──────┐              ┌──────────▼─────────┐  │
│  │ Service Accounts  │              │ Artifact Registry  │  │
│  │ - Discovery (RO)  │              │ - Docker Images    │  │
│  │ - Metadata Writer │              └────────────────────┘  │
│  │ - GKE Node        │                                      │
│  │ - Composer        │                                      │
│  └──────┬────────────┘                                      │
│         │                                                   │
│  ┌──────▼─────────────────────────────────┐                │
│  │ GCS Buckets                             │                │
│  │ - JSONL files (Vertex AI Search input) │                │
│  │ - Reports (Human-readable docs)        │                │
│  └─────────────────────────────────────────┘                │
│                                                              │
│  Optional Modules:                                          │
│  ├─ Dataplex Profiling (data quality scans)                │
│  └─ Vertex AI Search (semantic search infrastructure)      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- **GCP Project**: Active GCP project with billing enabled
- **Terraform**: Version >= 1.5.0 ([Install Guide](https://developer.hashicorp.com/terraform/downloads))
- **gcloud CLI**: Authenticated and configured ([Install Guide](https://cloud.google.com/sdk/docs/install))
- **Permissions**: Owner or Editor role on the project (for initial setup)
- **Existing Network**: VPC and subnet already configured, or use "default" VPC

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_ORG/data-discovery-infrastructure-gcp.git
cd data-discovery-infrastructure-gcp
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project details
```

**Minimum required variables:**

```hcl
project_id          = "your-gcp-project-id"
network             = "projects/your-gcp-project-id/global/networks/default"
subnetwork          = "projects/your-gcp-project-id/regions/us-central1/subnetworks/default"
jsonl_bucket_name   = "your-gcp-project-id-data-discovery-jsonl"
reports_bucket_name = "your-gcp-project-id-data-discovery-reports"
vertex_datastore_id = "your-vertex-datastore-id"
```

### 3. Authenticate with GCP

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default login
```

### 4. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

This will create all infrastructure components. The process takes approximately 10-15 minutes.

### 5. (Optional) Configure GKE Access

If you enabled GKE (`enable_gke = true`):

```bash
gcloud container clusters get-credentials data-discovery-cluster \
  --region us-central1 \
  --project YOUR_PROJECT_ID

# Create namespace and service accounts
kubectl create namespace data-discovery
kubectl create serviceaccount discovery-agent -n data-discovery
kubectl create serviceaccount metadata-writer -n data-discovery

# Annotate with GCP service accounts
kubectl annotate serviceaccount discovery-agent -n data-discovery \
  iam.gke.io/gcp-service-account=data-discovery-agent@YOUR_PROJECT_ID.iam.gserviceaccount.com

kubectl annotate serviceaccount metadata-writer -n data-discovery \
  iam.gke.io/gcp-service-account=data-discovery-metadata@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

See [QUICKSTART.md](QUICKSTART.md) for detailed step-by-step instructions.

## Configuration Options

### Core Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `project_id` | GCP Project ID | - | ✅ |
| `region` | GCP region | `us-central1` | ❌ |
| `network` | VPC network path | - | ✅ |
| `subnetwork` | VPC subnet path | - | ✅ |
| `jsonl_bucket_name` | JSONL bucket name | - | ✅ |
| `reports_bucket_name` | Reports bucket name | - | ✅ |
| `vertex_datastore_id` | Vertex AI Search datastore ID | - | ✅ |

### GKE Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_gke` | Enable GKE cluster deployment | `true` |
| `cluster_name` | GKE cluster name | `data-discovery-cluster` |
| `machine_type` | Node machine type | `e2-standard-2` |
| `min_node_count` | Minimum nodes | `1` |
| `max_node_count` | Maximum nodes | `5` |

Set `enable_gke = false` to skip GKE deployment and use Cloud Composer only.

### Cloud Composer Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `composer_env_name` | Composer environment name | `data-discovery-agent-composer` |
| `composer_image_version` | Airflow version | `composer-3-airflow-2.10.5` |

### Full Configuration Reference

See [terraform.tfvars.example](terraform.tfvars.example) for all available configuration options.

## Infrastructure Components

### Service Accounts

Four service accounts are created with least-privilege permissions:

1. **Discovery Service Account** (`data-discovery-agent`)
   - Purpose: Read-only data discovery operations
   - Permissions: BigQuery metadata viewer, Data Catalog viewer, Logging viewer, DLP reader
   
2. **Metadata Write Service Account** (`data-discovery-metadata`)
   - Purpose: Write enriched metadata to Data Catalog only
   - Permissions: Data Catalog entry group owner
   
3. **GKE Service Account** (`data-discovery-gke`) - Optional
   - Purpose: GKE node operations
   - Permissions: Logging and monitoring
   
4. **Composer Service Account** (`data-discovery-composer`)
   - Purpose: Airflow workflow orchestration
   - Permissions: BigQuery read/write, Data Catalog viewer, Vertex AI user, Dataplex admin

### GCS Buckets

Two regional buckets with lifecycle policies:

- **JSONL Bucket**: Stores JSONL files for Vertex AI Search ingestion
  - Lifecycle: Nearline after 30 days, delete after 90 days
  
- **Reports Bucket**: Stores Markdown reports for human consumption
  - Lifecycle: Nearline after 60 days, delete after 180 days

### Optional Modules

#### Dataplex Profiling

Automated data quality and profiling scans for BigQuery tables.

```bash
cd dataplex-profiling/
terraform init
terraform apply
```

See [dataplex-profiling/README.md](dataplex-profiling/README.md) for details.

#### Vertex AI Search

Infrastructure for semantic search over metadata.

```bash
cd vertex-ai-search/
terraform init
terraform apply
```

See [vertex-ai-search/README.md](vertex-ai-search/README.md) for details.

## Cost Estimation

Estimated monthly costs (us-central1 region):

| Component | Monthly Cost (USD) |
|-----------|-------------------|
| **Cloud Composer (Small)** | $300-400 |
| **GKE Cluster** (if enabled) | $123 |
| **GCS Storage** | $5-20 |
| **Vertex AI Search** | Variable (based on queries) |
| **Total** | ~$430-550 with GKE<br>~$305-430 without GKE |

> Costs vary based on usage. Use `enable_gke = false` to reduce costs.

## Security Features

- ✅ **Private GKE Cluster**: Nodes have no external IPs
- ✅ **Workload Identity**: Secure GCP API access without service account keys
- ✅ **Least Privilege IAM**: Minimal permissions for each service account
- ✅ **Read-Only Discovery**: Discovery service account cannot modify source data
- ✅ **Audit Logging**: All operations are logged to Cloud Logging
- ✅ **VPC Integration**: Uses existing VPC networks

## Terraform Commands

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# View outputs
terraform output

# Destroy infrastructure (⚠️ careful!)
terraform destroy
```

## Troubleshooting

### API Not Enabled

If you see "API not enabled" errors, wait 2-3 minutes and retry:

```bash
terraform apply
```

APIs take time to propagate after initial enablement.

### Network Not Found

Verify your network paths in `terraform.tfvars`:

```bash
gcloud compute networks list
gcloud compute networks subnets list --network=YOUR_NETWORK
```

### Workload Identity Issues

Verify IAM bindings:

```bash
gcloud iam service-accounts get-iam-policy \
  data-discovery-agent@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

See [QUICKSTART.md](QUICKSTART.md) for more troubleshooting steps.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Terraform best practices
- Use variables for all configurable values
- Never hardcode project-specific values
- Update documentation for any changes
- Test changes in a dev environment first

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

```
Copyright 2025 Contributors to the Data Discovery Infrastructure GCP project

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

## Support

For issues, questions, or contributions:

- 📝 [Open an Issue](https://github.com/YOUR_ORG/data-discovery-infrastructure-gcp/issues)
- 💬 [Discussions](https://github.com/YOUR_ORG/data-discovery-infrastructure-gcp/discussions)
- 📖 [Documentation](https://github.com/YOUR_ORG/data-discovery-infrastructure-gcp/tree/main/docs)

## Related Projects

- [Google Cloud Data Catalog](https://cloud.google.com/data-catalog)
- [Vertex AI Search](https://cloud.google.com/generative-ai-app-builder/docs/enterprise-search-introduction)
- [Dataplex](https://cloud.google.com/dataplex)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

## Acknowledgments

This infrastructure template follows Google Cloud best practices for security, cost optimization, and operational excellence.

---

**GitHub Topics**: `terraform`, `gcp`, `google-cloud`, `infrastructure-as-code`, `bigquery`, `data-discovery`, `gke`, `cloud-composer`, `vertex-ai`, `apache-2`

