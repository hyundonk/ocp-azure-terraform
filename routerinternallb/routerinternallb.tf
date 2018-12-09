###################################################################################
# Terraform script for openshift 2018.11.11

variable "location" {}
variable "subscription_id" {}

variable "tfbackend_storageaccount" {}
variable "access_key" {}

variable "internallb_routerIP" {}
 
variable "resourcegroup_name_cluster" {}
 
variable "prefix" {}

variable "vmnum_router" {}

provider "azurerm" {
	subscription_id = "${var.subscription_id}"
}

# Backend Configuration - Storage Account and Authentication
# For specifying Storage Account and storage account access key, use "-backend-config="storage_account_name=<value> -backend-config="access_key=<value>" at terraform init as below.
# terraform init -backend-config="storage_account_name=<value>" \
# -backend-config="access_key=<value>"

terraform {
	backend "azurerm" {
		#storage_account_name    = "ddptfbackend"
		container_name          = "tfstate"
		key                     = "ddp/routerinternallb.tfstate"
	}
}

data "terraform_remote_state" "network" {
  backend = "azurerm" 
  config {
    storage_account_name="${var.tfbackend_storageaccount}"
    container_name       = "tfstate"
    key                  = "ddp/network.tfstate"
    access_key="${var.access_key}"
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

# Internal LB for Router VMs
resource "azurerm_lb" "internallb_router" {
    name                = "${format("%s-router-internallb", var.prefix)}"
    location           = "${var.location}"
    resource_group_name  =  "${var.resourcegroup_name_cluster}"
    frontend_ip_configuration {
        name                 = "routerInternalFrontend"
        subnet_id = "${data.terraform_remote_state.network.subnet_extsub01_id}"
        private_ip_address = "${var.internallb_routerIP}"
        private_ip_address_allocation = "Static"
    }
}

resource "azurerm_lb_probe" "routerinternallb" {
    name                = "${format("%s-router-internallb-probe", var.prefix)}"
    resource_group_name  =  "${var.resourcegroup_name_cluster}"
    loadbalancer_id     = "${azurerm_lb.internallb_router.id}"
    protocol = "Tcp"
    port                = 80
}

resource "azurerm_lb_rule" "internallb_routerrule" {
    resource_group_name  =  "${var.resourcegroup_name_cluster}"
    loadbalancer_id                = "${azurerm_lb.internallb_router.id}"
    name                =   "${format("%s-router-internallb-rule-http", var.prefix)}"
    protocol                       = "Tcp"
    frontend_port                  = 80
    backend_port                   = 80
    frontend_ip_configuration_name = "routerInternalFrontend"
    backend_address_pool_id = "${azurerm_lb_backend_address_pool.internallb_router.id}"
    probe_id = "${azurerm_lb_probe.routerinternallb.id}"
    depends_on = ["azurerm_lb_probe.routerinternallb"]

    load_distribution = "SourceIPProtocol"
}

resource "azurerm_lb_rule" "internallb_httpsrouterrule" {
    resource_group_name  =  "${var.resourcegroup_name_cluster}"
    loadbalancer_id                = "${azurerm_lb.internallb_router.id}"
    name                =   "${format("%s-router-internallb-rule-https", var.prefix)}"
    protocol                       = "Tcp"
    frontend_port                  = 443
    backend_port                   = 443
    frontend_ip_configuration_name = "routerInternalFrontend"
    backend_address_pool_id = "${azurerm_lb_backend_address_pool.internallb_router.id}"
    probe_id = "${azurerm_lb_probe.routerinternallb.id}"
    depends_on = ["azurerm_lb_probe.routerinternallb"]

    load_distribution = "SourceIPProtocol"
}

resource "azurerm_lb_backend_address_pool" "internallb_router" {
    name                = "${format("%s-router-internallb-backend-pool", var.prefix)}"
    resource_group_name  =  "${var.resourcegroup_name_cluster}"
    loadbalancer_id     = "${azurerm_lb.internallb_router.id}"
}



resource "azurerm_network_interface_backend_address_pool_association" "internallb_router" {
    #network_interface_id    = "${element(azurerm_network_interface.router.*.id, count.index)}"
    network_interface_id    = "${data.terraform_remote_state.cluster.router_network_interface_ids[count.index]}"
    ip_configuration_name = "${join("", list("ipconfig", "0"))}"
    backend_address_pool_id = "${azurerm_lb_backend_address_pool.internallb_router.id}"

    count = "${var.vmnum_router}"
}
