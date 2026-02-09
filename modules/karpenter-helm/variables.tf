variable "karpenter_namespace" {
  description = "The Kubernetes namespace where Karpenter will be installed"
  type        = string
  default     = "karpenter"
}

variable "karpenter_name" {
  description = "The name of the Helm release for Karpenter"
  type        = string
  default     = "karpenter"
}

variable "karpenter_repository" {
  description = "The repository where Karpenter's Helm chart is stored"
  type        = string
  default     = "oci://public.ecr.aws/karpenter"
}


variable "karpenter_chart" {
  description = "The name of the Helm chart for Karpenter"
  type        = string
  default     = "karpenter"
}

variable "karpenter_version" {
  description = "The version of the Helm chart for Karpenter"
  type        = string
  default     = "1.1.0"
}


variable "cluster-name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "The Kubernetes API endpoint of the EKS cluster"
  type        = string
}

variable "karpenter_irsa_arn" {
  description = "The ARN of the IRSA used by Karpenter"
  type        = string
}

variable "karpenter_instance_profile_name" {
  description = "The name of the instance profile used by Karpenter"
  type        = string
}

variable "karpenter_queue_name" {
  description = "The name of the SQS queue used by Karpenter"
  type        = string
}

variable "karpenter_servicemonitor_enabled" {
  description = "Enable creation of servicemonitor for Karpenter"
  type        = bool
}
variable "requestsCpu" {
  type        = string
  default     = "1"
  description = "The amount of CPU resources to request for the container. Specified as a Kubernetes-compatible string (e.g., '500m' for half a CPU core or '1' for one CPU core)."
}

variable "limitsCpu" {
  type        = string
  default     = "1"
  description = "The maximum amount of CPU resources the container is allowed to use. Specified as a Kubernetes-compatible string (e.g., '1000m' for one CPU core or '2' for two CPU cores)."
}

variable "requestsMemory" {
  type        = string
  default     = "1Gi"
  description = "The amount of memory to request for the container. Specified as a Kubernetes-compatible string (e.g., '512Mi' for 512 MiB or '1Gi' for 1 GiB)."
}

variable "limitsMemory" {
  type        = string
  default     = "1Gi"
  description = "The maximum amount of memory the container is allowed to use. Specified as a Kubernetes-compatible string (e.g., '1Gi' for 1 GiB or '2Gi' for 2 GiB)."
}
