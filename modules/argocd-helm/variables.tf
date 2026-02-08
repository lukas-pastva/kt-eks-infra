variable "cluster-name" {
  type        = string
  default     = ""
  description = "EKS cluster name, used by the generated provider config"
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
