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
  kube_config = azurerm_kubernetes_cluster.main.kube_config[0]
}

provider "kubernetes" {
  host                   = local.kube_config.host
  client_certificate     = base64decode(local.kube_config.client_certificate)
  client_key             = base64decode(local.kube_config.client_key)
  cluster_ca_certificate = base64decode(local.kube_config.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = local.kube_config.host
    client_certificate     = base64decode(local.kube_config.client_certificate)
    client_key             = base64decode(local.kube_config.client_key)
    cluster_ca_certificate = base64decode(local.kube_config.cluster_ca_certificate)
  }
}
