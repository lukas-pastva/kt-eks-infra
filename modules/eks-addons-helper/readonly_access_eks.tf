resource "kubectl_manifest" "read_only_clusterrole" {
  count     = var.create_readonly_role ? 1 : 0
  force_new = true
  yaml_body = <<-YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: read-only-clusterrole
rules:
- apiGroups: ["*"]
  resources: 
    - bindings
    - componentstatuses
    - configmaps
    - endpoints
    - events
    - limitranges
    - namespaces
    - nodes
    - persistentvolumeclaims
    - persistentvolumes
    - pods
    - podtemplates
    - replicationcontrollers
    - resourcequotas
#    - secrets
    - serviceaccounts
    - services
    - challenges.acme.cert-manager.io
    - orders.acme.cert-manager.io
    - mutatingwebhookconfigurations.admissionregistration.k8s.io
    - validatingwebhookconfigurations.admissionregistration.k8s.io
    - customresourcedefinitions.apiextensions.k8s.io
    - apiservices.apiregistration.k8s.io
    - controllerrevisions.apps
    - daemonsets.apps
    - deployments.apps
    - replicasets.apps
    - statefulsets.apps
    - applications.argoproj.io
    - applicationsets.argoproj.io
    - appprojects.argoproj.io
    - tokenreviews.authentication.k8s.io
    - localsubjectaccessreviews.authorization.k8s.io
    - selfsubjectaccessreviews.authorization.k8s.io
    - selfsubjectrulesreviews.authorization.k8s.io
    - subjectaccessreviews.authorization.k8s.io
    - horizontalpodautoscalers.autoscaling
    - cronjobs.batch
    - jobs.batch
    - certificaterequests.cert-manager.io
    - certificates.cert-manager.io
    - clusterissuers.cert-manager.io
    - issuers.cert-manager.io
    - certificatesigningrequests.certificates.k8s.io
    - leases.coordination.k8s.io
    - eniconfigs.crd.k8s.amazonaws.com
    - endpointslices.discovery.k8s.io
    - ingressclassparams.elbv2.k8s.aws
    - targetgroupbindings.elbv2.k8s.aws
    - events.events.k8s.io
    - clusterexternalsecrets.external-secrets.io
    - clustersecretstores.external-secrets.io
    - externalsecrets.external-secrets.io
    - secretstores.external-secrets.io
    - flowschemas.flowcontrol.apiserver.k8s.io
    - prioritylevelconfigurations.flowcontrol.apiserver.k8s.io
    - awsnodetemplates.karpenter.k8s.aws
    - provisioners.karpenter.sh
    - nodes.metrics.k8s.io
    - pods.metrics.k8s.io
    - alertmanagerconfigs.monitoring.coreos.com
    - alertmanagers.monitoring.coreos.com
    - podmonitors.monitoring.coreos.com
    - probes.monitoring.coreos.com
    - prometheuses.monitoring.coreos.com
    - prometheusrules.monitoring.coreos.com
    - servicemonitors.monitoring.coreos.com
    - thanosrulers.monitoring.coreos.com
    - ingressclasses.networking.k8s.io
    - ingresses.networking.k8s.io
    - networkpolicies.networking.k8s.io
    - runtimeclasses.node.k8s.io
    - poddisruptionbudgets.policy
    - clusterrolebindings.rbac.authorization.k8s.io
    - clusterroles.rbac.authorization.k8s.io
    - rolebindings.rbac.authorization.k8s.io
    - roles.rbac.authorization.k8s.io
    - priorityclasses.scheduling.k8s.io
    - volumesnapshotclasses.snapshot.storage.k8s.io
    - volumesnapshotcontents.snapshot.storage.k8s.io
    - volumesnapshots.snapshot.storage.k8s.io
    - csidrivers.storage.k8s.io
    - csinodes.storage.k8s.io
    - csistoragecapacities.storage.k8s.io
    - storageclasses.storage.k8s.io
    - volumeattachments.storage.k8s.io
    - securitygrouppolicies.vpcresources.k8s.aws
    - clusterpolicyreports.wgpolicyk8s.io
    - policyreports.wgpolicyk8s.io
  verbs: ["get", "list", "watch"]
YAML
}

resource "kubectl_manifest" "read_only_clusterrolebinding" {
  count     = var.create_readonly_role ? 1 : 0
  force_new = true
  yaml_body = <<-YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-only-clusterrolebinding
subjects:
- kind: Group
  name: readonly
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: read-only-clusterrole
  apiGroup: rbac.authorization.k8s.io
YAML
}
