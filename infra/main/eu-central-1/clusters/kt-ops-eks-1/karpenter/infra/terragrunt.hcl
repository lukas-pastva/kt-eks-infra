terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-eks//modules/karpenter?ref=v19.8.0"
}
include "root" {
  path   = find_in_parent_folders()
  expose = true


  merge_strategy = "deep"
}
dependency "eks" {
  config_path = "${get_original_terragrunt_dir()}/../../eks"

  mock_outputs = {

    cluster_id              = "cluster-name"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-central-3.amazonaws.com/id/0000000000000000"
    node_groups             = {}
    aws_auth_configmap_yaml = yamlencode("")
  }
}

inputs = {
  cluster_name                    = dependency.eks.outputs.cluster_name
  irsa_oidc_provider_arn          = dependency.eks.outputs.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]
  create_iam_role                 = false
  iam_role_arn                    = dependency.eks.outputs.eks_managed_node_groups["default-a"].iam_role_arn
}
