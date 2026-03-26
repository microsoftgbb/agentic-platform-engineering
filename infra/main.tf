data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# 4-char numeric suffix for globally unique names (ACR, etc.)
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  lower   = false
  numeric = true
  special = false
}

locals {
  acr_name = var.acr_name != "" ? var.acr_name : "acragentic${random_string.suffix.result}"
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-agentic-demo"
  address_space       = ["10.0.0.0/8"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.240.0.0/16"]
}
