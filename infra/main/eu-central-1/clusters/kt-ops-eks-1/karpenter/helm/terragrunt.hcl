include "root" {
  path           = find_in_parent_folders()
  expose         = true
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

dependency "karpenter" {
  config_path = "${get_original_terragrunt_dir()}/../infra"
  mock_outputs = {
    iam_role_arn          = "arn:xxx"
    queue_name            = "xxxx"
  }
}

terraform {
  source = "../../../../../../../modules/karpenter-helm"
}

generate "provider-local" {
  path      = "provider-local.tf"
  if_exists = "overwrite"
  contents  = file("../../../../../../../provider-config/eks-addons-critical/eks-addons-critical.tf")
}

inputs = {
  cluster-name = dependency.eks.outputs.cluster_name

  namespace                        = "karpenter"
  name                             = "karpenter"
  repository                       = "oci://public.ecr.aws/karpenter"
  chart                            = "karpenter"
  version                          = "1.1.0"
  cluster_name                     = dependency.eks.outputs.cluster_name
  cluster_endpoint                 = dependency.eks.outputs.cluster_endpoint
  karpenter_irsa_arn               = dependency.karpenter.outputs.iam_role_arn
  karpenter_instance_profile_name  = ""
  karpenter_queue_name             = dependency.karpenter.outputs.queue_name
  karpenter_servicemonitor_enabled = false
  requestsCpu                      = "500m"
  limitsCpu                        = "500m"
  requestsMemory                   = "512Mi"
  limitsMemory                     = "512Mi"

  tags = merge(
    include.root.locals.custom_tags
  )

  eks = {
    "cluster_oidc_issuer_url" = dependency.eks.outputs.cluster_oidc_issuer_url
  }


}
