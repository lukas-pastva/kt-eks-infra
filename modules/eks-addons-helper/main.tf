resource "kubectl_manifest" "regcreds" {
  count     = var.create_regcreds == false ? 0 : 1
  force_new = true
  yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: regcreds
data:
  .dockerconfigjson: ${base64encode(jsonencode({
  auths : {
    "${var.registry_server}" : {
      auth : "${base64encode("${var.registry_username}:${var.registry_password}")}"
    }
  }
}))}
type: kubernetes.io/dockerconfigjson
YAML

}
