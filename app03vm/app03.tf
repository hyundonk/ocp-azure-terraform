###################################################################################
# Terraform script for adding app-03 VM 2019.01.02

variable "location" {}
variable "subscription_id" {}

variable "tfbackend_storageaccount" {}

variable "image_path" {} # URL for RHEL7.5 OS disk image (vhd)

variable "resourcegroup_name_cluster" {}
 
variable "prefix" {}

variable "vmsize_app03" {}

variable "adminUsername" {}
variable "adminPassword" {}
variable "access_key" {}

variable "bastion_private_IP" {}

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
        container_name          = "tfstate"
        key                     = "ddp/app03.tfstate"
    }
}

# terraform init -backend-config="storage_account_name=<value>"
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

#2.8.4 Application Instance Creation

resource "azurerm_network_interface" "app-03" {
    name                = "${format("%s-app-03-nic", var.prefix)}"
    location            = "${var.location}"
    resource_group_name  = "${var.resourcegroup_name_cluster}"
    
    ip_configuration {
        name = "${join("", list("ipconfig", "0"))}"
        subnet_id = "${data.terraform_remote_state.network.subnet_intsub01_id}"
        private_ip_address_allocation = "static"
        private_ip_address = "10.250.0.33"
    }

    internal_dns_name_label = "ocp-app-3"
    network_security_group_id = "${data.terraform_remote_state.network.nsg_app_id}"
    enable_accelerated_networking = "true"
}

resource "azurerm_virtual_machine" "app-03" {
    name                  = "${format("%s-app-03", var.prefix)}"
    location              = "${var.location}"
    resource_group_name  = "${var.resourcegroup_name_cluster}"
    vm_size               = "${var.vmsize_app03}"
    
    availability_set_id = "${data.terraform_remote_state.cluster.app_avset_id}"

    storage_image_reference {
        id = "${data.terraform_remote_state.cluster.rhel75_image_id}"
    }

    storage_os_disk {
        name          = "${format("%s-app-03-osdisk", var.prefix)}"
        caching       = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb = "127"
    }
    
    storage_data_disk {
        name          = "${format("%s-app-03-datadisk", var.prefix)}"
        managed_disk_type       = "Standard_LRS"
        create_option = "Empty"
        lun = 0
        disk_size_gb = "256"
    }
    
    os_profile {
        computer_name  = "${format("%s-app-03", var.prefix)}"
        admin_username = "${var.adminUsername}"
        admin_password = "${var.adminPassword}"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    network_interface_ids = ["${azurerm_network_interface.app-03.id}"]
}

