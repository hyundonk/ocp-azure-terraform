# Terraform script for openshift 2018.11.26
# Configure the Microsoft Azure Provider
# resource group for VPN resources

variable "location" {}
variable "subscription_id" {}

variable "shared_key" {}

variable "tfbackend_storageaccount" {}
variable "access_key" {}

variable "prefix" {}

provider "azurerm" {
	subscription_id = "${var.subscription_id}"
}

variable "address_space_SZDC" {
    type = "list"
}

variable "gateway_address_SZDC" {}

# Backend Configuration - Storage Account and Authentication
# For specifying Storage Account and storage account access key, use "-backend-config="storage_account_name=<value> -backend-config="access_key=<value>" at terraform init as below.
# terraform init -backend-config="storage_account_name=<value>" \
# -backend-config="access_key=<value>"

terraform {
  backend "azurerm" {
    #storage_account_name="ddptfbackend"
	container_name="tfstate"
	key="ddp/vpn.tfstate"
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

# Public IP Address for VPN Connection used by vnet gateway - Dynamic Allocation ONLY
resource "azurerm_public_ip" "vpngw_pip" {
  name                         = "ddc-vpngw-pip"
  #name                         = "${format("%s-vpngw-pip", var.prefix)}"
  location                     = "${var.location}"
  resource_group_name          = "${data.terraform_remote_state.network.network_resourcegroup_name}"
  public_ip_address_allocation = "dynamic"
}

# Create vNet Gateway for VPN Connection
resource "azurerm_virtual_network_gateway" "vpngw" {
  name                = "ddc-vpngw"
  #name                = "${format("%s-vpngw", var.prefix)}"
  location            = "${var.location}"
  resource_group_name          = "${data.terraform_remote_state.network.network_resourcegroup_name}"
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"

  ip_configuration {
    public_ip_address_id          = "${azurerm_public_ip.vpngw_pip.id}"
    private_ip_address_allocation = "Dynamic"
    subnet_id = "${data.terraform_remote_state.network.subnet_gatewaysubnet_id}"
  }
}

output "vpngw_public_ip_address" {
      value = "${azurerm_public_ip.vpngw_pip.ip_address}"
}


# Create Local Network Gateway for On Premise (SZDC) gateway connection
resource "azurerm_local_network_gateway" "localnetworkgw" {
  name                = "ddc-localnetgw-SZDC"
  #name                = "${format("%s-localnetgw-SZDC", var.prefix)}"
  resource_group_name          = "${data.terraform_remote_state.network.network_resourcegroup_name}"
  location            = "${var.location}"
  gateway_address     = "${var.gateway_address_SZDC}"
  address_space       = "${var.address_space_SZDC}"
}

# Create Connection Between vNet Gateway and VPN for Susie DC
resource "azurerm_virtual_network_gateway_connection" "conn_SZDC" {
  name                       = "ddc-vpnconnection-SZDC"
  #name                       = "${format("%s-vpnconnection-SZDC", var.prefix)}"
  location                   = "${var.location}"
  resource_group_name          = "${data.terraform_remote_state.network.network_resourcegroup_name}"
  type                       = "IPsec"
  virtual_network_gateway_id = "${azurerm_virtual_network_gateway.vpngw.id}"
  local_network_gateway_id   = "${azurerm_local_network_gateway.localnetworkgw.id}"
  shared_key                 = "${var.shared_key}"
}

