include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

dependency "eks" {
  config_path = "${get_original_terragrunt_dir()}/../eks"

  mock_outputs = {
    cluster_id              = "cluster-name"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-3.amazonaws.com/id/0000000000000000"
    node_groups             = {}
    aws_auth_configmap_yaml = yamlencode("")
  }
}

terraform {
  source = "${get_original_terragrunt_dir()}/../../../../../../modules/argocd-helm"
}

locals {
  component_values          = yamldecode(file("${find_in_parent_folders("component_values.yaml")}"))
  argocd_helmchart_versions = local.component_values["argocd_config"]["argocd_helmchart_versions"]
}

generate "provider-local" {
  path      = "provider-local.tf"
  if_exists = "overwrite"
  contents  = file("${get_original_terragrunt_dir()}/../../../../../../provider-config/eks-addons/eks-addons.tf")
}

inputs = {
  cluster-name = dependency.eks.outputs.cluster_name

  argocd_helm_config = {
    name                       = "argo-cd"
    chart                      = "argo-cd"
    repository                 = "https://argoproj.github.io/argo-helm"
    version                    = local.argocd_helmchart_versions
    namespace                  = "argo-cd"
    timeout                    = "1200"
    create_namespace           = true
    disable_openapi_validation = true
    values                     = [file("values.yaml")]
  }

  tags = merge(
    include.root.locals.custom_tags
  )
}
