variable "cluster-name" {
  type        = string
  description = "EKS cluster name"
}

variable "argocd_helm_config" {
  description = "ArgoCD Helm chart configuration"
  type        = any
  default     = {}
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
