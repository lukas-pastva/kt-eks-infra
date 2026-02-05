include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

dependency "policy" {
  config_path  = "${get_terragrunt_dir()}/../../policy/${basename(get_terragrunt_dir())}"
  mock_outputs = {
    arn = "arn::::::"
  }
}

dependency "eks" {
  config_path  = "${get_original_terragrunt_dir()}/../../../eks"
  mock_outputs = {
    cluster_id              = "cluster-name"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-3.amazonaws.com/id/0000000000000000"
    oidc_provider_arn       = "https://oidc.eks.eu-west-3.amazonaws.com/id/0000000000000000"
    node_groups             = {}
    aws_auth_configmap_yaml = yamlencode("")
  }
}

terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-assumable-role-with-oidc?ref=v5.11.2"
}

inputs = {
  role_name        = "${include.root.locals.full_name}-${basename(get_terragrunt_dir())}"
  create_role      = true
  role_policy_arns = [
    dependency.policy.outputs.arn
  ]
  number_of_role_policy_arns    = 1
  provider_url                  = dependency.eks.outputs.cluster_oidc_issuer_url
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:${basename(get_terragrunt_dir())}:${basename(get_terragrunt_dir())}"
  ]
  tags = merge(
    include.root.locals.custom_tags
  )
}
