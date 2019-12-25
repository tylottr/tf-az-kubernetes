terraform {
  backend azurerm {
    resource_group_name  = "tccloud-rg"
    storage_account_name = "tccloudsa"
    container_name       = "tfstate"
    key                  = "tf-az-kubernetes.terraform.tfstate"
  }
}
