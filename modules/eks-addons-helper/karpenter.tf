resource "kubectl_manifest" "aws_node_template" {
  for_each = var.aws_node_templates

  yaml_body = <<-EOT
apiVersion: karpenter.k8s.aws/v1alpha1
kind: AWSNodeTemplate
metadata:
  name: ${each.value.name}
spec:
  securityGroupSelector:
    ${each.value.security_group_key != null ? each.value.security_group_key : "karpenter.sh/discovery"}: ${each.value.security_group_value}
  subnetSelector:
    ${each.value.subnet_selector_key != null ? each.value.subnet_selector_key : "karpenter.sh/discovery"}: "${each.value.subnet_selector_value}"
  amiFamily: ${each.value.amiFamily != null ? each.value.amiFamily : "Bottlerocket"}
  tags:
    ${each.value.tag_key != null ? each.value.tag_key : "karpenter.sh/discovery"}: ${each.value.tag_value}
  EOT

}


resource "kubectl_manifest" "karpenter_provisioner" {
  for_each = var.provisioners

  yaml_body = <<-EOT
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: ${each.value.name}
spec:
  providerRef:
    name: ${each.value.provider_ref_name}
  ${try("taints:\n  - key: ${each.value.taint_key}\n    effect: ${each.value.taint_effect}\n    value: ${each.value.taint_value}", "")}
  ${try("startupTaints:\n  - key: ${each.value.startup_taint_key}\n    effect: ${each.value.startup_taint_effect}\n    value: ${each.value.startup_taint_value}", "")}
  ${try("labels:\n  ${each.value.label_key}: ${each.value.label_value}", "")}
  ${try("annotations:\n  ${each.value.annotation_key}: ${each.value.annotation_value}", "")}
  requirements: ${jsonencode(each.value.requirements)}
  ${try("kubeletConfiguration: ${jsonencode(each.value.kubelet_configuration)}", "")}
  limits:
    resources:
      cpu: "${each.value.cpu_limit}"
      memory: ${each.value.memory_limit}
  consolidation:
    enabled: ${each.value.consolidation_enabled}
  ${try("ttlSecondsUntilExpired: ${each.value.ttl_seconds_until_expired}", "")}
  ${try("ttlSecondsAfterEmpty: ${each.value.ttl_seconds_after_empty}", "")}
  ${try("weight: ${each.value.weight}", "")}
  EOT
  depends_on = [
    kubectl_manifest.aws_node_template
  ]
}




