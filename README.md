# KT-EKS-INFRA

AWS EKS Infrastructure as Code using Terragrunt.

---

## Quick Facts

| Setting | Value |
|---------|-------|
| AWS Region | `eu-central-1` |
| State Bucket | `sw-tronic-sk-tg-state-store` |
| Lock Table | `sw-tronic-sk-tg-state-lock` |
| Cluster Name | `kt-ops-eks-1` |
| Kubernetes Version | `1.28` |
| VPC CIDR | `10.240.64.0/21` |
| Domain | `jamf.fun` |

---

## Prerequisites

Install these tools on your machine:

```powershell
# Install via Chocolatey (run as Administrator)
choco install awscli -y
choco install terraform -y
choco install terragrunt -y
choco install kubectl -y
```

Verify installations:
```powershell
aws --version
terraform --version
terragrunt --version
kubectl version --client
```

---

## Step 1: Configure AWS CLI

```powershell
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
```powershell
aws sts get-caller-identity
```

---

## Step 2: Create S3 Bucket for Terraform State

```powershell
# Create the bucket
aws s3api create-bucket --bucket sw-tronic-sk-tg-state-store --region eu-central-1 --create-bucket-configuration LocationConstraint=eu-central-1

# Enable versioning
aws s3api put-bucket-versioning --bucket sw-tronic-sk-tg-state-store --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption --bucket sw-tronic-sk-tg-state-store --server-side-encryption-configuration '{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"},\"BucketKeyEnabled\":true}]}'

# Block public access
aws s3api put-public-access-block --bucket sw-tronic-sk-tg-state-store --public-access-block-configuration '{\"BlockPublicAcls\":true,\"IgnorePublicAcls\":true,\"BlockPublicPolicy\":true,\"RestrictPublicBuckets\":true}'
```

---

## Step 3: Create DynamoDB Table for State Locking

```powershell
aws dynamodb create-table `
    --table-name sw-tronic-sk-tg-state-lock `
    --attribute-definitions AttributeName=LockID,AttributeType=S `
    --key-schema AttributeName=LockID,KeyType=HASH `
    --billing-mode PAY_PER_REQUEST `
    --region eu-central-1
```

Verify table creation:
```powershell
aws dynamodb describe-table --table-name sw-tronic-sk-tg-state-lock --region eu-central-1
```

---

## Step 4: Update Configuration Values

Before deploying, update these files with your values:

### 4.1 Update AWS Account ID

File: `infra/main/env_values.yaml`
```yaml
aws_account_id: "YOUR_AWS_ACCOUNT_ID"  # Replace with your account ID
```

Get your account ID:
```powershell
aws sts get-caller-identity --query Account --output text
```

### 4.2 Update Global Values

File: `infra/global_values.yaml`
- Update `public_trusted_access_cidrs` with your IP addresses
- Update `ip_addressing_plan` if needed (VPC CIDR blocks)

### 4.3 Update Cluster Values

File: `infra/main/eu-central-1/clusters/kt-ops-eks-1/component_values.yaml`
- Update `cluster_admin_user` and `aws_account_admin_user` with your IAM user ARN
- Update ArgoCD settings if using GitOps

---

## Step 5: Deploy Infrastructure

Deploy in this order (dependencies matter):

```powershell
cd C:\git\git.jamf\kt-eks-infra

# 1. Deploy datasources (AWS region/AZ data)
cd infra/main/eu-central-1/datasources
terragrunt apply

# 2. Deploy VPC
cd ../clusters/kt-ops-eks-1/vpc
terragrunt apply

# 3. Deploy KMS keys for encryption
cd ../encryption-config
terragrunt apply

# 4. Deploy EKS cluster
cd ../eks
terragrunt apply

# 5. Deploy VPC endpoints
cd ../vpc-endpoints
terragrunt apply

# 6. Deploy critical addons (EBS CSI driver)
cd ../eks-addons-critical
terragrunt apply

# 7. Deploy Karpenter infrastructure
cd ../karpenter/infra
terragrunt apply

# 8. Deploy Karpenter Helm chart
cd ../helm
terragrunt apply

# 9. Deploy helper addons
cd ../../eks-addons-helper
terragrunt apply

# 10. Deploy Route53 zones (if using custom domain)
cd ../route53/zones
terragrunt apply

# 11. Deploy IAM roles for service accounts
cd ../iam/roles/aws-load-balancer-controller
terragrunt apply
# Repeat for other roles in iam/roles/

# 12. Deploy ArgoCD (if using GitOps)
cd ../../argo-cd
terragrunt apply
```

### Alternative: Deploy All at Once

```powershell
cd infra/main/eu-central-1
terragrunt run-all apply
```

**Note:** This will deploy everything but may fail on first run due to dependencies. Run again if needed.

---

## Step 6: Configure kubectl

After EKS is deployed:

```powershell
aws eks update-kubeconfig --name kt-ops-eks-1 --region eu-central-1
```

Verify connection:
```powershell
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
│   └── main/                       # Main environment
│       ├── env_values.yaml         # AWS account ID
│       ├── terragrunt.hcl          # Root config (state backend)
│       └── eu-central-1/           # Region
│           ├── datasources/        # AWS data sources
│           └── clusters/
│               └── kt-ops-eks-1/   # EKS cluster
│                   ├── vpc/
│                   ├── eks/
│                   ├── karpenter/
│                   ├── iam/
│                   └── ...
├── modules/                        # Custom Terraform modules
│   ├── addons-blueprints/          # EKS addons wrapper
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
- EKS 1.28 with private + public endpoint
- 3 managed node groups (Bottlerocket OS)
- CoreDNS, kube-proxy, VPC CNI addons
- Secrets encrypted with KMS

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

```powershell
# Plan changes
terragrunt plan

# Apply changes
terragrunt apply

# Destroy resources
terragrunt destroy

# Apply all in directory tree
terragrunt run-all apply

# Show state
terragrunt state list

# Refresh state
terragrunt refresh
```

---

## Troubleshooting

### State Lock Error
```powershell
# Force unlock (use with caution)
terragrunt force-unlock LOCK_ID
```

### Bucket Already Exists
S3 bucket names are globally unique. Change `sw-tronic-sk-tg-state-store` to a unique name in:
- `infra/main/terragrunt.hcl`

### EKS Auth Issues
```powershell
# Update kubeconfig
aws eks update-kubeconfig --name kt-ops-eks-1 --region eu-central-1

# Check cluster status
aws eks describe-cluster --name kt-ops-eks-1 --region eu-central-1
```

---

## Cleanup

To destroy all resources (in reverse order):

```powershell
cd infra/main/eu-central-1
terragrunt run-all destroy
```

Then manually delete:
```powershell
# Delete state bucket (must be empty first)
aws s3 rb s3://sw-tronic-sk-tg-state-store --force

# Delete lock table
aws dynamodb delete-table --table-name sw-tronic-sk-tg-state-lock --region eu-central-1
```
