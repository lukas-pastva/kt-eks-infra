module "addons-blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints.git//modules/kubernetes-addons?ref=v4.32.1"

  # EKS Data
  eks_cluster_id       = var.eks_cluster_id
  eks_oidc_provider    = var.eks_oidc_provider
  eks_cluster_endpoint = var.eks_cluster_endpoint
  eks_cluster_version  = var.eks_cluster_version

  enable_amazon_eks_vpc_cni            = var.enable_amazon_eks_vpc_cni
  enable_amazon_eks_coredns            = var.enable_amazon_eks_coredns
  enable_amazon_eks_kube_proxy         = var.enable_amazon_eks_kube_proxy
  enable_amazon_eks_aws_ebs_csi_driver = var.enable_amazon_eks_aws_ebs_csi_driver

  #K8s Add-ons

  # ArgoCD
  enable_argocd         = var.enable_argocd
  argocd_helm_config    = var.argocd_helm_config
  argocd_applications   = var.argocd_applications
  argocd_manage_add_ons = var.argocd_manage_add_ons

  enable_argo_workflows      = var.enable_argo_workflows
  argo_workflows_helm_config = var.argo_workflows_helm_config
  enable_argo_rollouts       = var.enable_argo_rollouts
  argo_rollouts_helm_config  = var.argo_rollouts_helm_config

  #ChaosMesh
  enable_chaos_mesh      = var.enable_chaos_mesh
  chaos_mesh_helm_config = var.chaos_mesh_helm_config

  #Cilium
  enable_cilium           = var.enable_cilium
  cilium_helm_config      = var.cilium_helm_config
  cilium_enable_wireguard = var.cilium_enable_wireguard

  enable_aws_load_balancer_controller          = var.enable_aws_load_balancer_controller
  enable_aws_node_termination_handler          = var.enable_aws_node_termination_handler
  enable_secrets_store_csi_driver              = var.enable_secrets_store_csi_driver
  enable_secrets_store_csi_driver_provider_aws = var.enable_secrets_store_csi_driver_provider_aws
  enable_cluster_autoscaler                    = var.enable_cluster_autoscaler
  enable_metrics_server                        = var.enable_metrics_server
  enable_kubecost                              = var.enable_kubecost
  tags                                         = var.tags
}