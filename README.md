# KT-EKS-INFRA

AWS EKS Infrastructure as Code using Terragrunt.

---

## Quick Facts

| Setting | Value |
|---------|-------|
| AWS Region | `eu-central-1` |
| State Bucket | `sw-tronic-sk-tg-state-store` |
| Lock Table | `sw-tronic-sk-tg-state-lock` |
| Cluster Name | `kt-dev-eks-1` |
| Kubernetes Version | `1.31` |
| VPC CIDR | `10.240.64.0/21` |
| Domain | `jamf.fun` |

---

## Prerequisites

This project requires a Linux/macOS environment (on Windows, use WSL). Upstream modules use symlinks that don't work on NTFS.

Install these tools:

```bash
# OpenTofu
curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
chmod +x install-opentofu.sh && ./install-opentofu.sh --install-method deb && rm install-opentofu.sh

# Terragrunt v0.72.6
curl -L "https://github.com/gruntwork-io/terragrunt/releases/download/v0.72.6/terragrunt_linux_amd64" -o /usr/local/bin/terragrunt
chmod +x /usr/local/bin/terragrunt

# AWS CLI, kubectl
apt-get install -y awscli kubectl
```

Enable provider caching (avoids re-downloading `hashicorp/aws` for every module):
```bash
echo 'export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"' >> ~/.bashrc
mkdir -p "$HOME/.terraform.d/plugin-cache"
source ~/.bashrc
```

Verify installations:
```bash
aws --version
tofu --version
terragrunt --version
kubectl version --client
```

---

## Step 1: Configure AWS CLI

```bash
aws configure
```

Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `eu-central-1`
- Default output format: `json`

<details>
<summary><strong>How to create AWS Access Keys (click to expand)</strong></summary>

1. **Go to AWS Console**: https://console.aws.amazon.com

2. **Go to IAM**:
   - Search for "IAM" in the top search bar
   - Click "IAM"

3. **Create a new IAM user**:
   - Click "Users" in the left sidebar
   - Click "Create user"
   - Username: `terraform-admin` (or any name)
   - Click "Next"

4. **Set permissions**:
   - Select "Attach policies directly"
   - Check `AdministratorAccess`
   - Click "Next" → "Create user"

5. **Create access keys**:
   - Click on the user you just created
   - Go to "Security credentials" tab
   - Scroll to "Access keys" → Click "Create access key"
   - Select "Command Line Interface (CLI)"
   - Check the confirmation box
   - Click "Next" → "Create access key"

6. **Save the keys**:
   - Copy **Access key ID**
   - Copy **Secret access key** (click "Show")
   - **Save these now** - you can't see the secret again!

</details>

Verify access:
```bash
aws sts get-caller-identity
```

---

## Step 2: Create S3 Bucket for Terraform State

```bash
# Create the bucket
aws s3api create-bucket --bucket sw-tronic-sk-tg-state-store --region eu-central-1 --create-bucket-configuration LocationConstraint=eu-central-1

# Enable versioning
aws s3api put-bucket-versioning --bucket sw-tronic-sk-tg-state-store --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption --bucket sw-tronic-sk-tg-state-store --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

# Block public access
aws s3api put-public-access-block --bucket sw-tronic-sk-tg-state-store --public-access-block-configuration '{"BlockPublicAcls":true,"IgnorePublicAcls":true,"BlockPublicPolicy":true,"RestrictPublicBuckets":true}'
```

---

## Step 3: Create DynamoDB Table for State Locking

```bash
aws dynamodb create-table \
    --table-name sw-tronic-sk-tg-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region eu-central-1
```

---

## Step 4: Create AWS Service-Linked Roles

These roles are required for EKS and Auto Scaling but don't exist in a fresh AWS account:

```bash
# Required for KMS encryption on Auto Scaling nodes
aws iam create-service-linked-role --aws-service-name autoscaling.amazonaws.com

# Required for EKS cluster
aws iam create-service-linked-role --aws-service-name eks.amazonaws.com

# Required for EC2 Spot instances (used by Karpenter)
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com
```

Note: You may get "already exists" errors if these roles exist - that's fine, ignore them.

---

## Step 5: Update Configuration Values

Before deploying, update these files with your values:

### 4.1 Update AWS Account ID

File: `infra/dev/env_values.yaml`
```yaml
aws_account_id: "YOUR_AWS_ACCOUNT_ID"  # Replace with your account ID
```

Get your account ID:
```bash
aws sts get-caller-identity --query Account --output text
```

### 4.2 Update Global Values

File: `infra/global_values.yaml`
- Update `public_trusted_access_cidrs` with your IP addresses
- Update `ip_addressing_plan` if needed (VPC CIDR blocks)

### 4.3 Update Cluster Values

File: `infra/dev/eu-central-1/clusters/kt-dev-eks-1/component_values.yaml`
- Update `cluster_admin_user` and `aws_account_admin_user` with your IAM user ARN
- Update ArgoCD settings if using GitOps

---

## Step 6: Deploy Route53 (Do This First!)

Deploy Route53 first - DNS propagation takes time, so set up NS records early:

```bash
cd infra/dev/eu-central-1/clusters/kt-dev-eks-1/route53/zones/jamf.fun
terragrunt apply
```

Copy the 4 nameservers from the output and add them to your domain registrar now.

---

## Step 7: Deploy Infrastructure

**Recommended:** Deploy everything at once - Terragrunt handles dependencies automatically:

```bash
cd infra/dev/eu-central-1
terragrunt run-all apply
```

This will deploy all components in the correct order based on the `dependency` blocks.

<details>
<summary><strong>Manual step-by-step deployment (click to expand)</strong></summary>

If you prefer to deploy components one by one (for debugging or understanding).
Items on the same layer can be applied in parallel.

```bash
cd infra/dev/eu-central-1/clusters/kt-dev-eks-1

# Layer 0 - No dependencies (can run in parallel)
tga encryption-config/
tga kms/infra-sops-kms/
tga iam/policy/cluster-autoscaler/
tga iam/policy/aws-load-balancer-controller/
tga iam/policy/exporter-cloudwatch/
tga iam/policy/external-dns/
tga route53/zones/jamf.fun/

# Layer 1 - Depends on Layer 0
tga vpc/                                     # depends on datasources

# Layer 2 - Depends on Layer 1
tga vpc-endpoints/                           # depends on vpc
tga eks/                                     # depends on vpc + encryption-config

# Layer 3 - Depends on Layer 2 (can run in parallel)
tga eks-addons-critical/                     # depends on vpc + eks
tga karpenter/infra/                         # depends on eks
tga eks-addons-helper/                       # depends on eks
tga iam/roles/cluster-autoscaler/            # depends on iam/policy + eks
tga iam/roles/aws-load-balancer-controller/  # depends on iam/policy + eks
tga iam/roles/exporter-cloudwatch/           # depends on iam/policy + eks
tga iam/roles/external-dns/                  # depends on iam/policy + eks

# Layer 4 - Depends on Layer 3
tga karpenter/helm/                          # depends on eks + karpenter/infra
tga argo-cd/                                 # depends on eks
```

**Important:** IAM policies must be applied before their corresponding roles.

</details>

---

## Step 8: Configure kubectl

After EKS is deployed:

```bash
aws eks update-kubeconfig --name kt-dev-eks-1 --region eu-central-1
```

Verify connection:
```bash
kubectl get nodes
kubectl get pods -A
```

---

## Project Structure

```
kt-eks-infra/
├── infra/                          # Infrastructure configs
│   ├── global_tags.yaml            # Tags for all resources
│   ├── global_values.yaml          # Global settings
│   └── dev/                        # Dev environment
│       ├── env_values.yaml         # AWS account ID
│       ├── terragrunt.hcl          # Root config (state backend)
│       └── eu-central-1/           # Region
│           ├── datasources/        # AWS data sources
│           └── clusters/
│               └── kt-dev-eks-1/   # EKS cluster
│                   ├── vpc/
│                   ├── eks/
│                   ├── karpenter/
│                   ├── iam/
│                   └── ...
├── modules/                        # Custom Terraform modules
│   ├── argocd-helm/                # ArgoCD via helm_release
│   ├── eks-addons-helper/          # Karpenter configs
│   └── karpenter-helm/             # Karpenter Helm
└── provider-config/                # Provider configs
```

---

## What Gets Created

### Networking
- VPC with CIDR `10.240.64.0/21`
- 3 private subnets + 3 public subnets
- 3 NAT Gateways (one per AZ)
- VPC Flow Logs
- S3 and KMS VPC endpoints

### EKS Cluster
- EKS 1.31 with private + public endpoint
- 3 managed node groups (Bottlerocket OS)
- CoreDNS, kube-proxy, VPC CNI (with prefix delegation), EBS CSI addons
- Secrets encrypted with KMS

> **Note:** EBS CSI driver is currently managed via `eks-addons-critical/` (particuleio module). A commented-out config exists in `eks/terragrunt.hcl` to migrate it to an EKS managed addon, but this requires manual Terraform state management to avoid PVC downtime.

### Auto-scaling
- Karpenter for dynamic node provisioning
- Spot + On-Demand instance support

### Security
- KMS keys for encryption
- IRSA (IAM Roles for Service Accounts)
- Restricted public access

### Optional
- ArgoCD for GitOps
- Route53 hosted zone
- ECS Fargate cluster

---

## Common Commands

```bash
# Plan changes
tgp

# Apply changes
tga

# Destroy resources
tgd

# Apply specific directory
tga ../some/path/

# Apply all in directory tree
terragrunt run-all apply

# Show state
terragrunt state list

# Refresh state
terragrunt refresh
```

---

## Bash aliases

Add to `~/.bashrc`:
```bash
tga() {
  if [ -n "$1" ]; then
    (cd "$1" && terragrunt apply)
  else
    terragrunt apply
  fi
}

tgd() {
  if [ -n "$1" ]; then
    (cd "$1" && terragrunt destroy)
  else
    terragrunt destroy
  fi
}

tgp() {
  if [ -n "$1" ]; then
    (cd "$1" && terragrunt plan)
  else
    terragrunt plan
  fi
}

tgi() {
  if [ -n "$1" ]; then
    (cd "$1" && terragrunt init)
  else
    terragrunt init
  fi
}
```

Then run `source ~/.bashrc`. Usage: `tga` (current dir) or `tga ../some/path/` (specific dir).

---

## Troubleshooting

### State Lock Error
```bash
# Force unlock (use with caution)
terragrunt force-unlock LOCK_ID
```

### Bucket Already Exists
S3 bucket names are globally unique. Change `sw-tronic-sk-tg-state-store` to a unique name in:
- `infra/dev/terragrunt.hcl`

### EKS Auth Issues
```bash
# Update kubeconfig
aws eks update-kubeconfig --name kt-dev-eks-1 --region eu-central-1

# Check cluster status
aws eks describe-cluster --name kt-dev-eks-1 --region eu-central-1
```

---

## Cleanup

To destroy all resources (in reverse order):

```bash
cd infra/dev/eu-central-1
terragrunt run-all destroy
```

Then manually delete:
```bash
# Delete state bucket (must be empty first)
aws s3 rb s3://sw-tronic-sk-tg-state-store --force

# Delete lock table
aws dynamodb delete-table --table-name sw-tronic-sk-tg-state-lock --region eu-central-1
```
