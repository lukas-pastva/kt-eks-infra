include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

dependency "eks" {
  config_path = "${get_original_terragrunt_dir()}/../eks"

  mock_outputs = {

    cluster_id              = "cluster-name"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-central-3.amazonaws.com/id/0000000000000000"
    node_groups             = {}
    aws_auth_configmap_yaml = yamlencode("")
  }
}

terraform {
  source = "../../../../../../modules/eks-addons-helper"
}

generate "provider-local" {
  path      = "provider-local.tf"
  if_exists = "overwrite"
  contents  = file("../../../../../../provider-config/eks-addons/eks-addons.tf")
}

inputs = {
  cluster-name               = dependency.eks.outputs.cluster_name
  ######################
  # Secrets management #
  ######################
  create_regcreds            = false

  provisioners = {
    ts = {
      name                 = "ts"
      provider_ref_name    = "ts"
      # taint_key            = "example.com/special-taint"
      # taint_effect         = "NoSchedule"
      # startup_taint_key    = "node.cilium.io/agent-not-ready"
      # startup_taint_effect = "NoExecute"
      # startup_taint_value  = "'true'"
      # label_key            = "billing-team"
      # label_value          = "my-team"
      # annotation_key       = "example.com/owner"
      # annotation_value     = "my-team"
      requirements         = [
        {
          key      = "karpenter.k8s.aws/instance-category"
          operator = "In"
          values   = ["c", "m", "t"]
        },
        {
          key      = "karpenter.k8s.aws/instance-cpu"
          operator = "In"
          values   = ["4", "8", "16"]
        },
        {
          key      = "karpenter.k8s.aws/instance-hypervisor"
          operator = "In"
          values   = ["nitro"]
        },
        {
          key      = "topology.kubernetes.io/zone"
          operator = "In"
          values   = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
        },
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["amd64"]
        },
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = ["spot", "on-demand"]
        }
      ]
      # kubelet_configuration = {
      #   #cluster_dns              = ["10.0.1.100"]
      #   container_runtime = "containerd"
      #   system_reserved   = { cpu = "100m", memory = "100Mi", ephemeral-storage = "1Gi" }
      #   kube_reserved     = { cpu = "200m", memory = "100Mi", ephemeral-storage = "3Gi" }
      #   # #eviction_hard            = { memory.available = "5%", nodefs.available = "10%", nodefs.inodesFree = "10%" }
      #   # eviction_soft            = { memory.available = "500Mi", nodefs.available = "15%", nodefs.inodesFree = "15%" }
      #   # eviction_soft_grace_period = { memory.available = "1m", nodefs.available = "1m30s", nodefs.inodesFree = "2m" }
      #   eviction_max_pod_grace_period = 60
      #   pods_per_core                 = 2
      #   max_pods                      = 20
      # }
      cpu_limit             = "128"
      memory_limit          = "256Gi"
      consolidation_enabled = true
      # ttl_seconds_until_expired = 2592000
      # ttl_seconds_after_empty   = 30
      # weight                    = 10
    }
  }

  aws_node_templates = {
    ts = {
      name                  = "ts"
      security_group_value  = dependency.eks.outputs.cluster_name
      subnet_selector_value = dependency.eks.outputs.cluster_name
      tag_value             = dependency.eks.outputs.cluster_name
      amiFamily             = "Bottlerocket"
      node_role             = dependency.eks.outputs.eks_managed_node_groups["default-a"].iam_role_name
    }
  }

  tags = merge(
    include.root.locals.custom_tags
  )
}
