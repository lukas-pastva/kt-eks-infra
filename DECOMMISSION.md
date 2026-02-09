# Decommission Guide

Complete teardown guide for the EKS infrastructure. Destroying this environment is **not** a simple `terragrunt run-all destroy` because Kubernetes operators create AWS resources (load balancers, DNS records, EBS volumes, EFS access points) that Terraform does not manage. These must be cleaned up first, or they will be orphaned and continue incurring costs.

## Prerequisites

- AWS CLI configured with appropriate credentials
- `kubectl` configured to access the cluster
- Terragrunt and OpenTofu installed

```bash
aws eks update-kubeconfig --name kt-dev-eks-1 --region eu-central-1
```

---

## Phase 1: Remove GitOps Applications (kt-eks-gitops)

ArgoCD manages applications that create AWS resources via operators. These must be removed **before** destroying infrastructure.

### 1.1 Delete application workloads

Remove applications in reverse wave order. Start with user-facing apps:

```bash
# Delete WordPress (removes Ingress -> LB, PVCs -> EBS/EFS volumes, DNS records)
kubectl delete application web-wordpress -n argo-cd

# Wait for resources to be cleaned up
kubectl wait --for=delete namespace/web-wordpress --timeout=300s
```

### 1.2 Delete infrastructure operators

Remove operators in the correct order. External-DNS and AWS LB Controller must stay alive long enough to clean up the resources they created.

```bash
# 1. Delete ingress resources first (triggers LB Controller to remove NLB/ALB and External-DNS to remove DNS records)
kubectl delete ingress --all -A
# Verify load balancers are gone
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `kt-dev-eks-1`) || contains(LoadBalancerName, `k8s-`)]' --region eu-central-1

# 2. Delete all remaining PVCs (triggers EBS CSI / EFS CSI to release volumes)
kubectl delete pvc --all -A

# 3. Now remove the operators themselves
kubectl delete application aws-efs-csi-driver -n argo-cd
kubectl delete application external-dns -n argo-cd
kubectl delete application cert-manager -n argo-cd
kubectl delete application ingress-nginx -n argo-cd
kubectl delete application aws-load-balancer-controller -n argo-cd
kubectl delete application metrics-server -n argo-cd

# 4. Remove namespace manager and app-of-apps
kubectl delete application app-of-apps-namespaces -n argo-cd
kubectl delete application app-of-apps -n argo-cd
```

### 1.3 Verify AWS resources are cleaned up

Before proceeding, verify that operator-created AWS resources are gone:

```bash
# Check for orphaned load balancers
aws elbv2 describe-load-balancers --region eu-central-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-`)].[LoadBalancerName,DNSName]' --output table

# Check for orphaned target groups
aws elbv2 describe-target-groups --region eu-central-1 \
  --query 'TargetGroups[?contains(TargetGroupName, `k8s-`)].[TargetGroupName]' --output table

# Check for orphaned EBS volumes (tagged by cluster)
aws ec2 describe-volumes --region eu-central-1 \
  --filters "Name=tag:kubernetes.io/cluster/kt-dev-eks-1,Values=owned" \
  --query 'Volumes[*].[VolumeId,State,Size]' --output table

# Check for orphaned DNS records in Route53
ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name jamf.fun --query 'HostedZones[0].Id' --output text)
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID \
  --query 'ResourceRecordSets[?Type!=`NS` && Type!=`SOA`].[Name,Type]' --output table

# Check for orphaned security groups (created by LB Controller)
aws ec2 describe-security-groups --region eu-central-1 \
  --filters "Name=tag:elbv2.k8s.aws/cluster,Values=kt-dev-eks-1" \
  --query 'SecurityGroups[*].[GroupId,GroupName]' --output table
```

If any orphaned resources remain, delete them manually before proceeding.

---

## Phase 2: Destroy Terragrunt-managed Helm Releases

```bash
cd infra/dev/eu-central-1/clusters/kt-dev-eks-1
```

Remove the Helm releases and addons that Terragrunt manages:

```bash
# ArgoCD (the GitOps controller itself)
terragrunt destroy --terragrunt-working-dir argo-cd/

# Karpenter Helm release (stops auto-scaling)
terragrunt destroy --terragrunt-working-dir karpenter/helm/

# EKS addons helper (Karpenter provisioners and node templates)
terragrunt destroy --terragrunt-working-dir eks-addons-helper/

# EKS critical addons (EBS CSI driver, snapshot controller)
terragrunt destroy --terragrunt-working-dir eks-addons-critical/
```

---

## Phase 3: Drain Nodes and Clean Up Kubernetes State

After removing operators and Helm releases, drain any remaining nodes:

```bash
# Cordon all nodes to prevent new scheduling
kubectl cordon $(kubectl get nodes -o name)

# Drain remaining workloads
kubectl drain --all --ignore-daemonsets --delete-emptydir-data --grace-period=30 --force

# Verify no Karpenter-managed nodes remain
kubectl get nodes -l karpenter.sh/registered=true
```

---

## Phase 4: Destroy Cluster Infrastructure

```bash
cd infra/dev/eu-central-1/clusters/kt-dev-eks-1

# Karpenter infrastructure (IAM role, SQS queue)
terragrunt destroy --terragrunt-working-dir karpenter/infra/

# ECS cluster (if deployed)
terragrunt destroy --terragrunt-working-dir ecs/

# EFS filesystem and mount targets
terragrunt destroy --terragrunt-working-dir efs/

# EKS cluster (this terminates all nodes and the control plane)
terragrunt destroy --terragrunt-working-dir eks/

# VPC endpoints
terragrunt destroy --terragrunt-working-dir vpc-endpoints/
```

---

## Phase 5: Destroy Networking and Security

```bash
cd infra/dev/eu-central-1/clusters/kt-dev-eks-1

# VPC (subnets, NAT gateways, internet gateway, route tables)
terragrunt destroy --terragrunt-working-dir vpc/

# Datasources
terragrunt destroy --terragrunt-working-dir ../../datasources/
```

---

## Phase 6: Destroy IAM, Encryption, and DNS

```bash
cd infra/dev/eu-central-1/clusters/kt-dev-eks-1

# IAM roles (IRSA)
terragrunt destroy --terragrunt-working-dir iam/roles/aws-load-balancer-controller/
terragrunt destroy --terragrunt-working-dir iam/roles/aws-efs-csi-driver/
terragrunt destroy --terragrunt-working-dir iam/roles/cluster-autoscaler/
terragrunt destroy --terragrunt-working-dir iam/roles/external-dns/

# IAM policies
terragrunt destroy --terragrunt-working-dir iam/policy/aws-load-balancer-controller/
terragrunt destroy --terragrunt-working-dir iam/policy/aws-efs-csi-driver/
terragrunt destroy --terragrunt-working-dir iam/policy/cluster-autoscaler/
terragrunt destroy --terragrunt-working-dir iam/policy/external-dns/

# KMS keys (scheduled for deletion with 30-day waiting period)
terragrunt destroy --terragrunt-working-dir encryption-config/
terragrunt destroy --terragrunt-working-dir kms/infra-sops-kms/

# Route53 hosted zone
terragrunt destroy --terragrunt-working-dir route53/zones/jamf.fun/
```

---

## Phase 7: Clean Up Terraform State Backend

The S3 state bucket and DynamoDB lock table are not managed by Terragrunt. Delete them manually:

```bash
# Empty and delete the state bucket
aws s3 rm s3://sw-tronic-sk-tg-state-store --recursive
aws s3 rb s3://sw-tronic-sk-tg-state-store

# Delete the lock table
aws dynamodb delete-table --table-name sw-tronic-sk-tg-state-lock --region eu-central-1
```

---

## Troubleshooting

### VPC deletion fails with "DependencyViolation"

ENIs or security groups are still attached. Common causes:
- Load balancers not fully deleted (check Phase 1.3)
- Lambda functions in VPC subnets (ENIs take up to 30 min to auto-delete)

```bash
# Find lingering ENIs
aws ec2 describe-network-interfaces --region eu-central-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'NetworkInterfaces[*].[NetworkInterfaceId,Description,Status]' --output table
```

### EKS deletion hangs

Usually caused by finalizers on Kubernetes resources or pods that won't terminate:

```bash
# Force delete all namespaces stuck in Terminating
kubectl get ns --field-selector status.phase=Terminating -o name | xargs -I {} kubectl patch {} -p '{"metadata":{"finalizers":[]}}' --type=merge

# Force delete pods stuck in Terminating
kubectl delete pods --all -A --force --grace-period=0
```

### Orphaned load balancers after teardown

If load balancers were not cleaned up before destroying the LB Controller:

```bash
# List and delete orphaned LBs
aws elbv2 describe-load-balancers --region eu-central-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-`)].[LoadBalancerArn]' --output text | \
  xargs -I {} aws elbv2 delete-load-balancer --load-balancer-arn {} --region eu-central-1

# Delete orphaned target groups
aws elbv2 describe-target-groups --region eu-central-1 \
  --query 'TargetGroups[?contains(TargetGroupName, `k8s-`)].[TargetGroupArn]' --output text | \
  xargs -I {} aws elbv2 delete-target-group --target-group-arn {} --region eu-central-1

# Delete orphaned security groups
aws ec2 describe-security-groups --region eu-central-1 \
  --filters "Name=tag:elbv2.k8s.aws/cluster,Values=kt-dev-eks-1" \
  --query 'SecurityGroups[*].GroupId' --output text | \
  xargs -I {} aws ec2 delete-security-group --group-id {} --region eu-central-1
```

### KMS key deleted accidentally

KMS keys have a 30-day waiting period before actual deletion. Cancel if needed:

```bash
aws kms cancel-key-deletion --key-id <key-id> --region eu-central-1
```

### Elastic IPs not released

NAT gateways allocate Elastic IPs. If VPC destroy fails midway, EIPs may be orphaned:

```bash
aws ec2 describe-addresses --region eu-central-1 \
  --query 'Addresses[?AssociationId==`null`].[AllocationId,PublicIp]' --output table
# Release unassociated EIPs
aws ec2 release-address --allocation-id <alloc-id> --region eu-central-1
```
