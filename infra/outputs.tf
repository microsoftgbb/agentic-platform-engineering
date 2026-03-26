output "resource_group_name" {
  description = "Name of the Azure Resource Group"
  value       = azurerm_resource_group.main.name
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "get_credentials_command" {
  description = "Command to fetch AKS kubeconfig"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "acr_login_server" {
  description = "ACR login server hostname"
  value       = azurerm_container_registry.main.login_server
}

output "acr_id" {
  description = "Resource ID of the Azure Container Registry (used for AKS role assignment)"
  value       = azurerm_container_registry.main.id
}

output "uami_client_id" {
  description = "Client ID of the User-Assigned Managed Identity (ARM_CLIENT_ID for GitHub Actions)"
  value       = azurerm_user_assigned_identity.workload.client_id
}

output "uami_principal_id" {
  description = "Principal ID of the User-Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.workload.principal_id
}

output "github_actions_env_vars" {
  description = "Environment variables / secrets to configure in GitHub Actions"
  value = {
    ARM_CLIENT_ID       = azurerm_user_assigned_identity.workload.client_id
    ARM_SUBSCRIPTION_ID = data.azurerm_client_config.current.subscription_id
    ARM_TENANT_ID       = data.azurerm_client_config.current.tenant_id
    ARM_USE_OIDC        = "true"
  }
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL of the AKS cluster (for federated credential configuration)"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "kube_config" {
  description = "Raw kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "argocd_admin_password" {
  description = "ArgoCD admin password — use with username 'admin'"
  value       = random_password.argocd_admin.result
  sensitive   = true
}
