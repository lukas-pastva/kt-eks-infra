# Karpenter v1.x: EC2NodeClass (replaces AWSNodeTemplate)
resource "kubectl_manifest" "ec2_node_class" {
  for_each = var.aws_node_templates

  yaml_body = <<-EOT
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: ${each.value.name}
spec:
  amiSelectorTerms:
    - alias: ${each.value.amiFamily != null ? lower(each.value.amiFamily) : "bottlerocket"}@latest
  securityGroupSelectorTerms:
    - tags:
        ${each.value.security_group_key != null ? each.value.security_group_key : "karpenter.sh/discovery"}: ${each.value.security_group_value}
  subnetSelectorTerms:
    - tags:
        ${each.value.subnet_selector_key != null ? each.value.subnet_selector_key : "karpenter.sh/discovery"}: "${each.value.subnet_selector_value}"
  role: ${each.value.node_role}
  tags:
    ${each.value.tag_key != null ? each.value.tag_key : "karpenter.sh/discovery"}: ${each.value.tag_value}
  EOT

}


# Karpenter v1.x: NodePool (replaces Provisioner)
resource "kubectl_manifest" "karpenter_nodepool" {
  for_each = var.provisioners

  yaml_body = <<-EOT
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: ${each.value.name}
spec:
  template:
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: ${each.value.provider_ref_name}
      ${try("taints:\n      - key: ${each.value.taint_key}\n        effect: ${each.value.taint_effect}\n        value: ${each.value.taint_value}", "")}
      ${try("startupTaints:\n      - key: ${each.value.startup_taint_key}\n        effect: ${each.value.startup_taint_effect}\n        value: ${each.value.startup_taint_value}", "")}
      requirements: ${jsonencode(each.value.requirements)}
  limits:
    cpu: "${each.value.cpu_limit}"
    memory: ${each.value.memory_limit}
  disruption:
    consolidationPolicy: ${each.value.consolidation_enabled ? "WhenEmptyOrUnderutilized" : "WhenEmpty"}
    consolidateAfter: 1m
  ${try("weight: ${each.value.weight}", "")}
  EOT
  depends_on = [
    kubectl_manifest.ec2_node_class
  ]
}




