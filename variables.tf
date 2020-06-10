###################
# Global Variables
###################
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

variable "resource_group_name" {
  description = "The name of an existing resource group - this will override the creation of a new resource group"
  type        = string
  default     = ""
}

variable "resource_prefix" {
  description = "A prefix for the name of the resource, used to generate the resource names"
  type        = string
}

variable "tags" {
  description = "Tags given to the resources created by this template"
  type        = map(string)
  default     = {}
}

##############################
# Resource-Specific Variables
##############################
# Azure Container Registry
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

variable "acr_georeplication_locations" {
  description = "Georeplication locations for ACR (Premium tier required)"
  type        = list
  default     = []
}

variable "enable_acr_admin" {
  description = "Flag used to enable ACR Admin"
  type        = bool
  default     = false
}

# AKS Cluster - Azure Level
variable "aks_kubernetes_version" {
  description = "Version of Kubernetes to use in the cluster"
  type        = string
  default     = null
}

variable "enable_aks_oms_monitoring" {
  description = "Flag used to enable Log Analytics"
  type        = string
  default     = false
}

variable "enable_aks_aad_rbac" {
  description = "Flag used to enable AAD RBAC Integration"
  type        = bool
  default     = false
}

variable "aks_aad_tenant_id" {
  description = "Tenant ID used for AAD RBAC (defaults to current tenant)"
  type        = string
  default     = null
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

variable "aks_subnet_name" {
  description = "Name of the subnet for Azure CNI (Ignored if enable_aks_advanced_networking is false)"
  type        = string
  default     = null
}

variable "aks_subnet_vnet_name" {
  description = "Name of the aks_subnet_name's VNet for Azure CNI (Ignored if enable_aks_advanced_networking is false)"
  type        = string
  default     = null
}

variable "aks_subnet_vnet_resource_group_name" {
  description = "Name of the resource group for aks_subnet_vnet_name for Azure CNI (Ignored if enable_aks_advanced_networking is false)"
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

variable "aks_node_min_count" {
  description = "Minimum number of nodes in the AKS cluster"
  type        = number
  default     = 1
}

variable "aks_node_max_count" {
  description = "Maximum number of nodes in the AKS cluster"
  type        = number
  default     = 1
}

# AKS Cluster - Cluster Level
variable "aks_nginx_ingress_values_file" {
  description = "Path to a custom values file used to deploy Nginx Ingress"
  type        = string
  default     = ""
}

variable "aks_nginx_ingress_chart_version" {
  description = "The chart version for the nginx-ingress Helm chart"
  type        = string
  default     = "1.29.2"
}

#########
# Locals
#########
locals {
  resource_prefix = "${var.resource_prefix}-aks"
}
