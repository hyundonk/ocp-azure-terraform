# Terraform script for DNS zone resource

variable "location" {}
variable "subscription_id" {}

variable "tfbackend_storageaccount" {}
variable "access_key" {}

variable "dnszone_name" {}

provider "azurerm" {
	subscription_id = "${var.subscription_id}"
}

# Backend Configuration - Storage Account and Authentication
# For specifying Storage Account and storage account access key, use "-backend-config="storage_account_name=<value> -backend-config="access_key=<value>" at terraform init as below.
# terraform init -backend-config="storage_account_name=<value>" \
# -backend-config="access_key=<value>"

terraform {
  backend "azurerm" {
    #storage_account_name="ddptfbackend"
	container_name="tfstate"
	key="ddp/dnszone.tfstate"
  }
}

data "terraform_remote_state" "cluster" {
  backend = "azurerm" 
  config {
    storage_account_name="${var.tfbackend_storageaccount}"
    container_name       = "tfstate"
    key                  = "ddp/cluster.tfstate"
    access_key="${var.access_key}"
  }
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "rg" {
  name     = "ddp-dnszone"
  location = "${var.location}"
}

resource "azurerm_dns_zone" "zone" {
    name = "${var.dnszone_name}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    zone_type = "Public"
}

resource "azurerm_dns_a_record" "router" {
    name                = "*.apps"
    zone_name = "${azurerm_dns_zone.zone.name}"
    resource_group_name  =  "${azurerm_resource_group.rg.name}"
    ttl                 = 300
    records             = ["${data.terraform_remote_state.cluster.routerLB_public_ip_address}"]
}

resource "azurerm_dns_a_record" "bastion" {
    name                = "bastion"
    zone_name = "${azurerm_dns_zone.zone.name}"
    resource_group_name  =  "${azurerm_resource_group.rg.name}"
    ttl                 = 300
    records             = ["${data.terraform_remote_state.cluster.bastion_public_ip_address}"]
}

resource "azurerm_dns_a_record" "webconsole" {
    name                = "@"  ##validate this
    zone_name = "${azurerm_dns_zone.zone.name}"
    resource_group_name  =  "${azurerm_resource_group.rg.name}"
    ttl                 = 300
    records             = ["${data.terraform_remote_state.cluster.master_public_ip_address}"]
}

resource "azurerm_dns_a_record" "admin" {
    name                = "admin"
    zone_name = "${azurerm_dns_zone.zone.name}"
    resource_group_name  =  "${azurerm_resource_group.rg.name}"
    ttl                 = 300
    records             = ["${data.terraform_remote_state.cluster.master_public_ip_address}"]
}

resource "azurerm_dns_a_record" "api" {
    name                = "api"
    zone_name = "${azurerm_dns_zone.zone.name}"
    resource_group_name  =  "${azurerm_resource_group.rg.name}"
    ttl                 = 300
    records             = ["${data.terraform_remote_state.cluster.master_public_ip_address}"]
}

resource "azurerm_dns_a_record" "logs" {     #for application logs
    name                = "logs"
    zone_name = "${azurerm_dns_zone.zone.name}"
    resource_group_name  =  "${azurerm_resource_group.rg.name}"
    ttl                 = 300
    records             = ["${data.terraform_remote_state.cluster.routerLB_public_ip_address}"]
}
resource "azurerm_dns_a_record" "metrics" {    #for prometheus metrics
    name                = "metrics"
    zone_name = "${azurerm_dns_zone.zone.name}"
    resource_group_name  =  "${azurerm_resource_group.rg.name}"
    ttl                 = 300
    records             = ["${data.terraform_remote_state.cluster.routerLB_public_ip_address}"]
}
resource "azurerm_dns_a_record" "ops" {       #for future istio integration
    name                = "ops"
    zone_name = "${azurerm_dns_zone.zone.name}"
    resource_group_name  =  "${azurerm_resource_group.rg.name}"
    ttl                 = 300
    records             = ["${data.terraform_remote_state.cluster.routerLB_public_ip_address}"]
}

output "name_servers" {
      value = "${azurerm_dns_zone.zone.name_servers}"
}

output "name_server_id" {
      value = "${azurerm_dns_zone.zone.id}"
}


