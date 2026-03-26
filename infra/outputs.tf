output "resource_group_name" {
  description = "Name of the Azure Resource Group"
  value       = azurerm_resource_group.main.name
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = var.cluster_name
}

output "get_credentials_command" {
  description = "Command to fetch AKS kubeconfig"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${var.cluster_name}"
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
  description = "Client ID of the User-Assigned Managed Identity (for workload identity annotations)"
  value       = try(azurerm_user_assigned_identity.main.client_id, "")
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL of the AKS cluster (for federated credential configuration)"
  value       = try(azurerm_kubernetes_cluster.main.oidc_issuer_url, "")
}

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}
