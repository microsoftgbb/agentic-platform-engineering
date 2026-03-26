resource "helm_release" "aks_mcp" {
  name             = "aks-mcp"
  repository       = "oci://ghcr.io/azure/aks-mcp/charts"
  chart            = "aks-mcp"
  version          = var.aks_mcp_chart_version
  namespace        = kubernetes_namespace.aks_mcp.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.aks_mcp.metadata[0].name
  }

  set {
    name  = "podLabels.azure\\.workload\\.identity/use"
    value = "true"
  }

  set {
    name  = "env.AZURE_CLIENT_ID"
    value = azurerm_user_assigned_identity.workload.client_id
  }

  set {
    name  = "env.AZURE_TENANT_ID"
    value = data.azurerm_client_config.current.tenant_id
  }

  set {
    name  = "service.port"
    value = "8000"
  }

  depends_on = [
    kubernetes_namespace.aks_mcp,
    kubernetes_service_account.aks_mcp
  ]
}
