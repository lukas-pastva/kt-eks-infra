terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-eks//modules/karpenter?ref=v20.31.0"
}
include "root" {
  path   = find_in_parent_folders()
  expose = true
  merge_strategy = "deep"
}
dependency "eks" {
  config_path = "${get_original_terragrunt_dir()}/../../eks"

  mock_outputs = {
    cluster_name            = "cluster-name"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-central-1.amazonaws.com/id/0000000000000000"
    oidc_provider_arn       = "arn:aws:iam::111122223333:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/XXXXX"
    eks_managed_node_groups = {
      "default-a" = {
        iam_role_name  = "mock-role-name"
        iam_role_arn   = "arn:aws:iam::111122223333:role/mock-role"
        node_group_arn = "arn:aws:eks:eu-central-1:111122223333:nodegroup/cluster/default-a/mock"
      }
    }
  }
}

inputs = {
  cluster_name = dependency.eks.outputs.cluster_name

  # Enable IRSA
  enable_irsa                     = true
  irsa_oidc_provider_arn          = dependency.eks.outputs.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  # Node IAM role
  create_node_iam_role = false
  node_iam_role_arn    = dependency.eks.outputs.eks_managed_node_groups["default-a"].iam_role_arn

  # Access entry is already created by the EKS module
  create_access_entry = false

  tags = merge(
    include.root.locals.custom_tags
  )
}
