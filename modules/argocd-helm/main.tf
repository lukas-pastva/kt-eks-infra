resource "helm_release" "argocd" {
  name                       = var.argocd_helm_config.name
  chart                      = var.argocd_helm_config.chart
  repository                 = var.argocd_helm_config.repository
  version                    = var.argocd_helm_config.version
  namespace                  = var.argocd_helm_config.namespace
  timeout                    = try(var.argocd_helm_config.timeout, 1200)
  create_namespace           = try(var.argocd_helm_config.create_namespace, true)
  disable_openapi_validation = try(var.argocd_helm_config.disable_openapi_validation, false)

  values = try(var.argocd_helm_config.values, [])
}
