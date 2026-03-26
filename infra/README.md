# Agentic Platform Engineering — Infrastructure

This Terraform configuration provisions a complete Azure-hosted platform for the agentic-platform-engineering workshop: an AKS cluster with workload identity, a container registry, ArgoCD for GitOps, and the AKS MCP Server for AI-assisted cluster management — all wired together with GitHub Actions OIDC so no long-lived secrets are required.

## Prerequisites

| Tool | Minimum version |
|------|----------------|
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az`) | Latest, authenticated (`az login`) |
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.7 |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Latest |
| [helm](https://helm.sh/docs/intro/install/) | Latest |

You also need a fork or clone of [MicrosoftGbb/agentic-platform-engineering](https://github.com/MicrosoftGbb/agentic-platform-engineering) — the `github_org` and `github_repo` variables must match your fork.

## What Gets Provisioned

| Resource | Details |
|----------|---------|
| **Resource Group** | `rg-agentic-demo` (configurable) |
| **Virtual Network** | `vnet-agentic-demo`, `10.0.0.0/8` |
| **AKS Subnet** | `snet-aks`, `10.240.0.0/16` |
| **AKS Cluster** | `aks-eastus2`, Kubernetes 1.30, `Standard_D4s_v3` × 3 nodes, OIDC issuer + workload identity enabled, Azure CNI |
| **Azure Container Registry** | Basic SKU, auto-named `acragentic<4-digit-suffix>` (or set `acr_name`). AKS kubelet identity gets `AcrPull`. |
| **User-Assigned Managed Identity** | `uami-agentic-workload` — Contributor on the resource group, AKS Cluster Admin |
| **Federated Identity Credentials** | 5 total: GitHub env `copilot`, GitHub env `demo`, branch `main`, pull requests, and the `aks-mcp` Kubernetes service account |
| **ArgoCD** | Helm chart `7.3.4`, namespace `argocd`, LoadBalancer service, notifications controller enabled, random 16-char admin password |
| **AKS MCP Server** | Helm chart `0.1.0` from `oci://ghcr.io/azure/aks-mcp/charts`, namespace `aks-mcp`, port 8000, workload identity via dedicated service account |

## Quick Start

```bash
# 1. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set github_org and github_repo at minimum

# 2. Initialize
terraform init

# 3. Plan
terraform plan

# 4. Apply (~15 min)
terraform apply
```

## After Apply

```bash
# Connect to the cluster
$(terraform output -raw get_credentials_command)

# Get GitHub Actions secrets to configure
terraform output -json github_actions_env_vars

# Get ArgoCD admin password (username: admin)
terraform output -raw argocd_admin_password

# Access ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Open https://localhost:8080

# Access AKS MCP server
$(terraform output -raw aks_mcp_port_forward_command)
# Server listening on http://localhost:8000
```

## GitHub Actions Setup

After `terraform apply`, configure the following **repository secrets** in your GitHub fork (values come from `terraform output -json github_actions_env_vars`):

| Secret | Value |
|--------|-------|
| `ARM_CLIENT_ID` | Client ID of the managed identity |
| `ARM_SUBSCRIPTION_ID` | Your Azure subscription ID |
| `ARM_TENANT_ID` | Your Azure tenant ID |
| `ARM_USE_OIDC` | `true` |

Also create two **GitHub Environments** named exactly `copilot` and `demo` (Settings → Environments). The federated credentials are scoped to these environment names — workflows using other environment names will fail to authenticate.

## Remote State (Optional)

By default Terraform stores state locally. For team or CI use, migrate to Azure Storage:

```bash
# 1. Create storage account (one-time)
az group create -n rg-terraform-state -l eastus2
az storage account create -n <your-storage-account> -g rg-terraform-state --sku Standard_LRS
az storage container create -n tfstate --account-name <your-storage-account>

# 2. Copy backend.tf.example to backend.tf and fill in values
cp backend.tf.example backend.tf
# Edit backend.tf — set storage_account_name

# 3. Migrate existing state
terraform init -reconfigure
```

## Variables Reference

| Variable | Description | Default |
|----------|-------------|---------|
| `location` | Azure region for all resources | `eastus2` |
| `resource_group_name` | Name of the Azure Resource Group | `rg-agentic-demo` |
| `cluster_name` | Name of the AKS cluster | `aks-eastus2` |
| `kubernetes_version` | Kubernetes version for the AKS cluster | `1.30` |
| `node_vm_size` | VM size for the AKS default node pool | `Standard_D4s_v3` |
| `node_count` | Number of nodes in the default node pool | `3` |
| `acr_name` | ACR name — auto-generated as `acragentic<suffix>` if empty | `""` |
| `github_org` | GitHub org for OIDC federation (**required**) | — |
| `github_repo` | GitHub repo name for OIDC federation (**required**) | — |
| `argocd_chart_version` | Helm chart version for ArgoCD | `7.3.4` |
| `aks_mcp_chart_version` | Helm chart version for the AKS MCP Server | `0.1.0` |
| `tags` | Tags applied to all resources | `{project, managed_by}` |

## Outputs Reference

| Output | Description | Sensitive |
|--------|-------------|-----------|
| `resource_group_name` | Name of the Azure Resource Group | No |
| `cluster_name` | Name of the AKS cluster | No |
| `get_credentials_command` | `az aks get-credentials` command ready to run | No |
| `acr_login_server` | ACR login server hostname | No |
| `acr_id` | Resource ID of the ACR | No |
| `uami_client_id` | Client ID of the managed identity (`ARM_CLIENT_ID`) | No |
| `uami_principal_id` | Principal ID of the managed identity | No |
| `github_actions_env_vars` | Map of all GitHub Actions secrets to configure | No |
| `oidc_issuer_url` | OIDC issuer URL of the AKS cluster | No |
| `vnet_id` | Resource ID of the Virtual Network | No |
| `aks_subnet_id` | Resource ID of the AKS subnet | No |
| `kube_config` | Raw kubeconfig for the AKS cluster | **Yes** |
| `argocd_admin_password` | ArgoCD admin password (username: `admin`) | **Yes** |
| `aks_mcp_port_forward_command` | `kubectl port-forward` command for the AKS MCP server | No |
