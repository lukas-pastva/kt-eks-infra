include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

dependency "eks" {
  config_path = "${get_original_terragrunt_dir()}/../../../eks"

  mock_outputs = {
    cluster_id              = "cluster-name"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-3.amazonaws.com/id/0000000000000000"
    oidc_provider_arn       = "https://oidc.eks.eu-west-3.amazonaws.com/id/0000000000000000"
    node_groups             = {}
    aws_auth_configmap_yaml = yamlencode("")
  }
}

dependency "policy" {
  config_path = "../../policy/argo-sops-kms"
  mock_outputs = {
    arn = "arn::::::"
  }
}

terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks?ref=v5.11.2"
}

locals {
  role_name = "${basename(get_terragrunt_dir())}"
}

inputs = {
  role_name = "${include.root.locals.full_name}-${local.role_name}"

  role_policy_arns = {
    helm-secrets-policy = dependency.policy.outputs.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = dependency.eks.outputs.oidc_provider_arn
      namespace_service_accounts = ["${basename(get_terragrunt_dir())}:${basename(get_terragrunt_dir())}"]
    }
  }

  tags = merge(
    include.root.locals.custom_tags
  )

}
