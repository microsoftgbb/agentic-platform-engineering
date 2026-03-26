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
