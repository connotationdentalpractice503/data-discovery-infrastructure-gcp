# Quick Start Guide - Data Discovery Infrastructure

Get your data discovery infrastructure up and running in 15 minutes.

## Prerequisites Check

Before starting, ensure you have:

| Tool | Required Version | Check Command |
|------|-----------------|---------------|
| `terraform` | >= 1.5.0 | `terraform version` |
| `gcloud` | Latest | `gcloud version` |
| `kubectl` | Latest | `kubectl version --client` |

## Step 1: Authenticate with GCP

```bash
# Login to GCP
gcloud auth login

# Set your project
export PROJECT_ID="YOUR_PROJECT_ID"
gcloud config set project ${PROJECT_ID}

# Configure application default credentials
gcloud auth application-default login
```

## Step 2: Prepare Configuration

```bash
# Clone the repository
git clone https://github.com/YOUR_ORG/data-discovery-infrastructure-gcp.git
cd data-discovery-infrastructure-gcp

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars
```

## Step 3: Edit Configuration

Open `terraform.tfvars` and set these required values:

```hcl
# GCP Project Configuration
project_id = "YOUR_PROJECT_ID"
region     = "us-central1"

# Network Configuration
# Option 1: Use default VPC
network    = "default"
subnetwork = "default"

# Option 2: Use existing VPC (replace with your values)
# network    = "projects/YOUR_PROJECT_ID/global/networks/YOUR_NETWORK"
# subnetwork = "projects/YOUR_PROJECT_ID/regions/us-central1/subnetworks/YOUR_SUBNET"

# Storage Configuration
jsonl_bucket_name   = "YOUR_PROJECT_ID-data-discovery-jsonl"
reports_bucket_name = "YOUR_PROJECT_ID-data-discovery-reports"

# GKE Configuration (set to false to skip GKE)
enable_gke = true

# Vertex AI Search Configuration
vertex_datastore_id = "data-discovery-metadata"  # You'll create this later
```

## Step 4: Initialize Terraform

```bash
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

## Step 5: Review the Plan

```bash
terraform plan
```

Review the resources that will be created:
- Cloud Composer environment
- GKE cluster (if enabled)
- 2 GCS buckets
- 4 service accounts
- Artifact Registry repository
- IAM bindings
- Monitoring resources

## Step 6: Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. Deployment takes approximately **10-15 minutes**.

### What Gets Created

| Resource | Purpose | Estimated Time |
|----------|---------|----------------|
| Cloud Composer | Airflow orchestration | 10-12 minutes |
| GKE Cluster | Container workloads (optional) | 5-8 minutes |
| GCS Buckets | Storage | < 1 minute |
| Service Accounts | Authentication | < 1 minute |
| Artifact Registry | Container images | < 1 minute |

## Step 7: Configure Kubernetes (GKE Only)

**Skip this step if you set `enable_gke = false`**

```bash
# Connect to your GKE cluster
gcloud container clusters get-credentials data-discovery-cluster \
  --region us-central1 \
  --project ${PROJECT_ID}

# Verify connection
kubectl get nodes
```

### Create Kubernetes Service Accounts

```bash
# Create namespace
kubectl create namespace data-discovery

# Create service accounts
kubectl create serviceaccount discovery-agent -n data-discovery
kubectl create serviceaccount metadata-writer -n data-discovery

# Annotate for Workload Identity
kubectl annotate serviceaccount discovery-agent -n data-discovery \
  iam.gke.io/gcp-service-account=data-discovery-agent@${PROJECT_ID}.iam.gserviceaccount.com

kubectl annotate serviceaccount metadata-writer -n data-discovery \
  iam.gke.io/gcp-service-account=data-discovery-metadata@${PROJECT_ID}.iam.gserviceaccount.com
```

## Step 8: Verify Deployment

```bash
# View Terraform outputs
terraform output

# Check GCS buckets
gsutil ls -L gs://${PROJECT_ID}-data-discovery-jsonl
gsutil ls -L gs://${PROJECT_ID}-data-discovery-reports

# Check service accounts
gcloud iam service-accounts list --project=${PROJECT_ID}

# Check Composer environment
gcloud composer environments list --locations=us-central1

# (If GKE enabled) Check cluster
kubectl get all -n data-discovery
```

## Step 9: Create Vertex AI Search Datastore (Optional)

```bash
gcloud alpha discovery-engine data-stores create data-discovery-metadata \
  --project=${PROJECT_ID} \
  --location=global \
  --collection=default_collection \
  --industry-vertical=GENERIC \
  --content-config=CONTENT_REQUIRED \
  --solution-type=SOLUTION_TYPE_SEARCH
```

Verify creation:

```bash
gcloud alpha discovery-engine data-stores list \
  --project=${PROJECT_ID} \
  --location=global
```

## Step 10: Test Access (GKE Only)

Test that Workload Identity is working:

```bash
kubectl run -it --rm --restart=Never test-pod \
  --serviceaccount=discovery-agent \
  --namespace=data-discovery \
  --image=google/cloud-sdk:slim \
  -- gcloud auth list
```

Expected output: `data-discovery-agent@YOUR_PROJECT_ID.iam.gserviceaccount.com`

## What's Next?

### Deploy Dataplex Profiling (Optional)

```bash
cd dataplex-profiling/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with tables to profile
terraform init
terraform apply
```

See [dataplex-profiling/README.md](dataplex-profiling/README.md)

### Push Docker Images to Artifact Registry

```bash
# Configure Docker authentication
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build and tag your image
docker build -t your-app:latest .
docker tag your-app:latest \
  us-central1-docker.pkg.dev/${PROJECT_ID}/data-discovery/your-app:latest

# Push to registry
docker push us-central1-docker.pkg.dev/${PROJECT_ID}/data-discovery/your-app:latest
```

See [ARTIFACT_REGISTRY.md](ARTIFACT_REGISTRY.md)

### Deploy Your Application

Create Kubernetes deployments using the service accounts and Artifact Registry images.

## Cost Management

### View Current Costs

```bash
# Check current month costs
gcloud billing accounts list
gcloud billing projects describe ${PROJECT_ID}
```

### Reduce Costs

**Disable GKE** (saves ~$123/month):
```hcl
# In terraform.tfvars
enable_gke = false
```

**Scale Down Composer**:
Edit `composer.tf` to reduce worker counts.

**Use Spot Instances** (for GKE):
Modify node pool configuration in `main.tf`.

## Troubleshooting

### "API not enabled" Error

Wait 2-3 minutes after first apply, then retry:

```bash
terraform apply
```

### "Permission denied" Error

Grant yourself necessary roles:

```bash
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="user:YOUR_EMAIL@example.com" \
  --role="roles/editor"
```

### Network Not Found

List available networks:

```bash
gcloud compute networks list
gcloud compute networks subnets list --network=default
```

Update `terraform.tfvars` with correct network paths.

### Can't Connect to GKE Cluster

Re-authenticate:

```bash
gcloud auth login
gcloud auth application-default login

# Reconnect to cluster
gcloud container clusters get-credentials data-discovery-cluster \
  --region us-central1 \
  --project ${PROJECT_ID}
```

### Terraform State Lock

If terraform gets stuck:

```bash
# Only use if you're certain no other apply is running
terraform force-unlock LOCK_ID
```

## Cleanup

### Destroy Everything

⚠️ **Warning**: This deletes all resources and data!

```bash
# Backup important data first
gsutil -m cp -r gs://${PROJECT_ID}-data-discovery-reports ./backup/

# Destroy infrastructure
terraform destroy
```

Type `yes` when prompted.

### Destroy Selectively

Remove only GKE cluster:

```bash
terraform destroy -target=google_container_cluster.data_discovery
terraform destroy -target=google_container_node_pool.primary_nodes
```

## Getting Help

- **Documentation**: [README.md](README.md)
- **Terraform Issues**: Check `terraform validate` and `terraform plan`
- **GCP Console**: View resources at https://console.cloud.google.com
- **Logs**: Check Cloud Logging for detailed error messages

## Estimated Time Breakdown

| Step | Time | Can Run in Parallel |
|------|------|---------------------|
| Prerequisites | 5 min | - |
| Configuration | 2 min | - |
| Terraform Apply | 10-15 min | ✅ Cloud Composer + GKE |
| GKE Setup | 3 min | - |
| Vertex AI Setup | 2 min | - |
| **Total** | **20-25 min** | |

## Next Steps

After completing this quickstart:

1. ✅ Review [README.md](README.md) for detailed configuration options
2. ✅ Set up [Dataplex Profiling](dataplex-profiling/README.md) for data quality
3. ✅ Configure [Vertex AI Search](vertex-ai-search/README.md) for semantic search
4. ✅ Deploy your data discovery applications
5. ✅ Set up Cloud Scheduler for automated discovery workflows

---

**Need more details?** See the full [README.md](README.md) for comprehensive documentation.

