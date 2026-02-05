resource "helm_release" "karpenter" {

  namespace        = var.karpenter_namespace
  create_namespace = true

  name       = var.karpenter_name
  repository = var.karpenter_repository
  chart      = var.karpenter_chart
  version    = var.karpenter_version

  # Karpenter v1.x settings
  set {
    name  = "settings.clusterName"
    value = var.cluster-name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = var.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.karpenter_irsa_arn
  }

  set {
    name  = "settings.interruptionQueue"
    value = var.karpenter_queue_name
  }

  set {
    name  = "serviceMonitor.enabled"
    value = var.karpenter_servicemonitor_enabled
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = var.requestsCpu
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = var.limitsCpu
  }
  set {
    name  = "controller.resources.requests.memory"
    value = var.requestsMemory
  }

  set {
    name  = "controller.resources.limits.memory"
    value = var.limitsMemory
  }

}
