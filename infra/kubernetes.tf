resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_namespace" "aks_mcp" {
  metadata {
    name = "aks-mcp"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "azure.workload.identity/use"  = "true"
    }
  }
}

resource "kubernetes_service_account" "aks_mcp" {
  metadata {
    name      = "aks-mcp"
    namespace = kubernetes_namespace.aks_mcp.metadata[0].name
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.workload.client_id
    }
    labels = {
      "azure.workload.identity/use" = "true"
    }
  }
}
