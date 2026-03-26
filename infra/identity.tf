resource "azurerm_user_assigned_identity" "workload" {
  name                = "uami-agentic-workload"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

# Environment: copilot
resource "azurerm_federated_identity_credential" "gh_env_copilot" {
  name                = "github-env-copilot"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_org}/${var.github_repo}:environment:copilot"
}

# Environment: demo
resource "azurerm_federated_identity_credential" "gh_env_demo" {
  name                = "github-env-demo"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_org}/${var.github_repo}:environment:demo"
}

# Branch: main
resource "azurerm_federated_identity_credential" "gh_branch_main" {
  name                = "github-branch-main"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
}

# Pull requests
resource "azurerm_federated_identity_credential" "gh_pr" {
  name                = "github-pull-request"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_org}/${var.github_repo}:pull_request"
}

resource "azurerm_federated_identity_credential" "aks_mcp_sa" {
  name                = "aks-mcp-service-account"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject             = "system:serviceaccount:aks-mcp:aks-mcp"
}

# Contributor on the resource group (deploy AKS, ACR, etc.)
resource "azurerm_role_assignment" "workload_rg_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

# AKS cluster admin (for kubectl access in workflows)
resource "azurerm_role_assignment" "workload_aks_admin" {
  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}
