variable "create_regcreds" {
  type        = bool
  default     = false
  description = "create K8s secret to authenticate on the image registry"
}

variable "registry_server" {
  type        = string
  default     = "ghcr.io"
  description = "Github imnage registry"
}

variable "registry_username" {
  type        = string
  default     = "bot"
  description = "Github imnage registry"
}
variable "registry_password" {
  type        = string
  description = "Github imnage registry"
  sensitive   = true
  default     = "ChangePassword"
}
variable "create_readonly_role" {
  description = "Whether to create the read-only ClusterRole and ClusterRoleBinding"
  type        = bool
  default     = false
}


# https://karpenter.sh/docs/concepts/nodeclasses/

variable "aws_node_templates" {
  type = map(object({
    name                  = string
    security_group_key    = optional(string)
    security_group_value  = string
    subnet_selector_key   = optional(string)
    subnet_selector_value = string
    tag_key               = optional(string)
    tag_value             = string
    amiFamily             = optional(string)
    node_role             = string  # Required for Karpenter v1.x EC2NodeClass
  }))
  default     = {}
  description = "This variable defines EC2NodeClass for Karpenter v1.x"
}

# https://karpenter.sh/docs/concepts/nodepools/
variable "provisioners" {
  type = map(object({
    name                 = string
    provider_ref_name    = string
    taint_key            = optional(string)
    taint_effect         = optional(string)
    taint_value          = optional(string)
    startup_taint_key    = optional(string)
    startup_taint_effect = optional(string)
    startup_taint_value  = optional(string)
    label_key            = optional(string)
    label_value          = optional(string)
    annotation_key       = optional(string)
    annotation_value     = optional(string)
    requirements = list(object({
      key      = string
      operator = string
      values   = list(string)
    }))
    kubelet_configuration = optional(object({
      cluster_dns                   = optional(list(string))
      container_runtime             = optional(string)
      system_reserved               = optional(map(string))
      kube_reserved                 = optional(map(string))
      eviction_hard                 = optional(map(string))
      eviction_soft                 = optional(map(string))
      eviction_soft_grace_period    = optional(map(string))
      eviction_max_pod_grace_period = optional(number)
      pods_per_core                 = optional(number)
      max_pods                      = optional(number)
    }))
    cpu_limit                 = string
    memory_limit              = string
    consolidation_enabled     = bool
    ttl_seconds_until_expired = optional(number)
    ttl_seconds_after_empty   = optional(number)
    weight                    = optional(number)
  }))
  default = {}
}
