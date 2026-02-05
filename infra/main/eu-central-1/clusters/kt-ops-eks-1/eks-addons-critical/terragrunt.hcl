include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

dependency "vpc" {
  config_path = "${get_original_terragrunt_dir()}/../vpc"

  mock_outputs = {
    private_subnet_ids = [
      "subnet-00000000",
      "subnet-00000001",
      "subnet-00000002"
    ]
  }
}

dependency "eks" {
  config_path = "${get_original_terragrunt_dir()}/../eks"

  mock_outputs = {
    cluster_id              = "cluster-name"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-central-1.amazonaws.com/id/0000000000000000"
    oidc_provider_arn       = "https://oidc.eks.eu-central-3.amazonaws.com/id/0000000000000000"
    node_groups             = {}
    aws_auth_configmap_yaml = yamlencode("")
  }
}

terraform {
  source = "github.com/particuleio/terraform-kubernetes-addons.git//modules/aws?ref=v14.0.1"
}

locals {
  component_values = yamldecode(file("${find_in_parent_folders("component_values.yaml")}"))
  cluster_external_dns_domain_filter = local.component_values["cluster_external_dns_domain_filter"]
}

generate "snapshot-controller-patch" {
  path      = "snapshot-controller-patch.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    resource "kubectl_manifest" "snapshot_controller_toleration_patch" {
      count     = var.csi-external-snapshotter["enabled"] ? 1 : 0
      yaml_body = <<-YAML
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: snapshot-controller
          namespace: kube-system
        spec:
          template:
            spec:
              tolerations:
                - key: CriticalAddonsOnly
                  operator: Exists
      YAML

      force_conflicts   = true
      server_side_apply = true

      depends_on = [kubectl_manifest.csi-external-snapshotter]
    }
  EOF
}

generate "provider-local" {
  path      = "provider-local.tf"
  if_exists = "overwrite"
  contents  = file("../../../../../../provider-config/eks-addons-critical/eks-addons-critical.tf")
}

inputs = {

  priority-class = {
    name  = basename(get_terragrunt_dir())
    value = "90000"
  }

  priority-class-ds = {
    name   = "${basename(get_terragrunt_dir())}-ds"
    values = "100000"
  }

  cluster-name = dependency.eks.outputs.cluster_name

  tags = merge(
    include.root.locals.custom_tags
  )

  eks = {
    "cluster_oidc_issuer_url" = dependency.eks.outputs.cluster_oidc_issuer_url
    "oidc_provider_arn"       = dependency.eks.outputs.oidc_provider_arn
  }

  csi-external-snapshotter = {
    enabled = true
    version = "v7.0.2"
  }

  aws-ebs-csi-driver = {
    enabled          = true
    is_default_class = true
    wait             = false
    use_encryption   = true
    use_kms          = true
  }

}
