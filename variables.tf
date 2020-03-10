# Global
variable "tenant_id" {
  description = "The tenant id of this deployment"
  type        = string
  default     = null
}

variable "subscription_id" {
  description = "The subscription id of this deployment"
  type        = string
  default     = null
}

variable "client_id" {
  description = "The client id used to authenticate to Azure"
  type        = string
  default     = null
}

variable "client_secret" {
  description = "The client secret used to authenticate to Azure"
  type        = string
  default     = null
}

variable "location" {
  description = "The location of this deployment"
  type        = string
  default     = "UK South"
}

variable "resource_prefix" {
  description = "A prefix for the name of the resource, used to generate the resource names"
  type        = string
  default     = "kubernetes"
}

variable "tags" {
  description = "Tags given to the resources created by this template"
  type        = map(string)
  default     = {}
}

# Resource-specific
## Azure Container Registry
variable "enable_acr" {
  description = "Flag used to enable ACR"
  type        = bool
  default     = false
}

variable "acr_sku" {
  description = "SKU of the ACR"
  type        = string
  default     = "Basic"
}

variable "acr_admin_enabled" {
  description = "Flag used to enable ACR Admin"
  type        = bool
  default     = false
}

## AKS Cluster
### Azure-level
variable "aks_kubernetes_version" {
  description = "Version of Kubernetes to use in the cluster"
  type        = string
  default     = null
}

variable "enable_aks_la_monitoring" {
  description = "Flag used to enable Log Analytics"
  type        = string
  default     = false
}

variable "enable_aks_aad_rbac" {
  description = "Flag used to enable AAD RBAC Integration"
  type        = bool
  default     = false
}

variable "aks_aad_client_app_id" {
  description = "App ID of the client application used for AAD RBAC"
  type        = string
  default     = null
}

variable "aks_aad_server_app_id" {
  description = "App ID of the server application used for AAD RBAC"
  type        = string
  default     = null
}

variable "aks_aad_server_app_secret" {
  description = "App Secret of the server application used for AAD RBAC"
  type        = string
  default     = null
}

variable "enable_aks_calico" {
  description = "Flag used to enable Calico CNI (Ignored if enable_aks_advanced_networking is true)"
  type        = bool
  default     = false
}

variable "enable_aks_advanced_networking" {
  description = "Flag used to enable Azure CNI"
  type        = bool
  default     = false
}

variable "aks_subnet_id" {
  description = "Subnet ID for Azure CNI (Ignored if enable_aks_advanced_networking is false)"
  type        = string
  default     = null
}

variable "aks_service_cidr" {
  description = "Service CIDR for AKS"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_node_size" {
  description = "Size of nodes in the AKS cluster"
  type        = string
  default     = "Standard_B2ms"
}

variable "aks_node_disk_size" {
  description = "Disk size of nodes in the AKS cluster (Minimum 30)"
  type        = number
  default     = 64
}

variable "aks_node_min_count" {
  description = "Minimum number of nodes in the AKS cluster"
  type        = number
  default     = 1
}

variable "aks_node_max_count" {
  description = "Maximum number of nodes in the AKS cluster"
  type        = number
  default     = 5
}

### K8s-level
variable "aks_nginx_ingress_chart_version" {
  description = "The chart version for the nginx-ingress Helm chart"
  type        = string
  default     = "1.29.2"
}

variable "aks_cert_manager_chart_version" {
  description = "The chart version for the cert-manager Helm chart"
  type        = string
  default     = "v0.13.0"
}

# Locals
locals {
  resource_prefix = "${var.resource_prefix}-aks"

  tags = merge(
    var.tags,
    {
      deployedBy = "Terraform"
    }
  )

  vm_admin_username = "vmadmin"
}
