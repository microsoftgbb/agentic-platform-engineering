# ---------------------------------------------------------------------------
# OIDC authentication for GitHub Actions
# Set the following environment variables in your workflow (no secrets needed):
#   ARM_USE_OIDC=true
#   ARM_TENANT_ID=<tenant-id>
#   ARM_SUBSCRIPTION_ID=<subscription-id>
#   ARM_CLIENT_ID=<user-assigned-managed-identity-client-id>
# ---------------------------------------------------------------------------

provider "azurerm" {
  features {}
  # Credentials are sourced from ARM_* environment variables.
  # No hardcoded values here — safe for public repos.
}

provider "azuread" {
  # Tenant is sourced from ARM_TENANT_ID / AZURE_TENANT_ID env var.
}

# ---------------------------------------------------------------------------
# Kubernetes and Helm providers are configured from the AKS cluster outputs
# defined in aks.tf. The try() calls below allow `terraform validate` and
# `terraform plan` to succeed before aks.tf resources exist.
# ---------------------------------------------------------------------------

locals {
  kube_host                   = try(azurerm_kubernetes_cluster.main.kube_config[0].host, "")
  kube_client_certificate     = try(base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_certificate), "")
  kube_client_key             = try(base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_key), "")
  kube_cluster_ca_certificate = try(base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate), "")
}

provider "kubernetes" {
  host                   = local.kube_host
  client_certificate     = local.kube_client_certificate
  client_key             = local.kube_client_key
  cluster_ca_certificate = local.kube_cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = local.kube_host
    client_certificate     = local.kube_client_certificate
    client_key             = local.kube_client_key
    cluster_ca_certificate = local.kube_cluster_ca_certificate
  }
}
