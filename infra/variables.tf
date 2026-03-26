variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-agentic-demo"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-eastus2"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.30"
}

variable "node_vm_size" {
  description = "VM size for AKS default node pool"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "node_count" {
  description = "Number of nodes in the AKS default node pool"
  type        = number
  default     = 3
}

variable "acr_name" {
  description = "Azure Container Registry name. If empty, auto-generated as acragentic<random_suffix>"
  type        = string
  default     = ""
}

variable "github_org" {
  description = "GitHub org for OIDC federation"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo name for OIDC federation"
  type        = string
}

variable "argocd_chart_version" {
  description = "Helm chart version for ArgoCD"
  type        = string
  default     = "7.3.4"
}

variable "aks_mcp_chart_version" {
  description = "Helm chart version for the AKS MCP Server"
  type        = string
  default     = "0.1.0"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    project    = "agentic-platform-engineering"
    managed_by = "terraform"
  }
}
