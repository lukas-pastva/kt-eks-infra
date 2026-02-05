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

# https://github.com/aws-ia/terraform-aws-eks-blueprints/issues/825
terraform {
  source = "${get_original_terragrunt_dir()}/../../../../../../modules/addons-blueprints"
}

locals {
  component_values          = yamldecode(file("${find_in_parent_folders("component_values.yaml")}"))
  argocd_fqdn               = local.component_values["argocd_config"]["argocd_fqdn"]
  argocd_helmchart_versions = local.component_values["argocd_config"]["argocd_helmchart_versions"]
}

generate "provider-local" {
  path      = "provider-local.tf"
  if_exists = "overwrite"
  contents  = file("${get_original_terragrunt_dir()}/../../../../../../provider-config/eks-addons-critical/eks-addons-critical.tf")
}

inputs = {
  cluster-name = dependency.eks.outputs.cluster_name

  aws = {
    "region" = include.root.locals.merged.aws_region
  }

  eks_cluster_id       = dependency.eks.outputs.cluster_name
  eks_cluster_endpoint = dependency.eks.outputs.cluster_endpoint
  eks_oidc_provider    = dependency.eks.outputs.oidc_provider
  eks_cluster_version  = dependency.eks.outputs.cluster_version

  # Wait on the `kube-system` profile before provisioning addons
  data_plane_wait_arn = join(",", [for group in dependency.eks.outputs.eks_managed_node_groups : group.node_group_arn])

  # Add-ons

  enable_argocd      = true
  argocd_helm_config = {
    name             = "argo-cd"
    chart            = "argo-cd"
    repository       = "https://argoproj.github.io/argo-helm"
    version          = local.argocd_helmchart_versions
    namespace        = "argo-cd"
    timeout          = "1200"
    create_namespace = true
    values           = [
      templatefile("values.yaml", {
        "argocd_fqdn"          = local.argocd_fqdn
        "allowed_cidr"         = "${join(",", concat(include.root.locals.public_trusted_access_cidrs))},127.0.0.1/32",
        "kms_access_role_arn"  = "",
        "argocd_git_token"     = "",
        "full_name"            = include.root.locals.full_name
      })
    ]
  }
  argocd_applications = {
    root-argo = {
      path               = "${dependency.eks.outputs.cluster_name}/chart"
      repo_url           = "https://github.com/helm/argo-cd-observability-cluster.git"
      project            = "default"
      target_revision    = "main"
      add_on_application = true
    }
  }

  tags = merge(
    include.root.locals.custom_tags
  )

}