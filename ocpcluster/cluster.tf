###################################################################################
# Terraform script for openshift 2018.11.11

variable "location" {}
variable "subscription_id" {}

variable "tfbackend_storageaccount" {}

variable "image_path" {} # URL for RHEL7.5 OS disk image (vhd)


variable "resourcegroup_name_cluster" {}

variable "internallb_masterIP" {}
variable "internallb_routerIP" {}
 
variable "prefix" {}

variable "vmsize_master" {}
variable "vmsize_infra" {}
variable "vmsize_router" {}
variable "vmsize_app" {}
variable "vmsize_bastion" {}

variable "vmnum_master" {}
variable "vmnum_infra" {}
variable "vmnum_router" {}
variable "vmnum_app" {}

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
        key                     = "ddp/cluster.tfstate"
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

resource "azurerm_resource_group" "resourcegroup" {
        name     = "${var.resourcegroup_name_cluster}"
        location    = "${var.location}"
}

resource "azurerm_image" "image" {
    name = "RHEL7.5"
    location             = "${var.location}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"

    os_disk {
        os_type = "Linux"
        os_state = "Generalized"
        blob_uri = "${var.image_path}"
        size_gb = 127
    }
}

# 2.7.1 Master Load Balancer

# external LB
resource "azurerm_public_ip" "pip_masterexternallb" {
    name                  = "${format("%s-master-externallb-pip", var.prefix)}"
    location            = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.resourcegroup.name}"
    public_ip_address_allocation = "static"
}

resource "azurerm_lb" "externallb_master" {
    name                = "${format("%s-master-externallb", var.prefix)}"
    location           = "${var.location}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    frontend_ip_configuration {
        name                 = "masterExternalFrontend"
        public_ip_address_id = "${azurerm_public_ip.pip_masterexternallb.id}"
    }
}

resource "azurerm_lb_probe" "lb_probe_masterexternallb" {
    name                = "${format("%s-master-externallb-probe", var.prefix)}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    loadbalancer_id     = "${azurerm_lb.externallb_master.id}"
    protocol = "Tcp"
    port                = 443
}

resource "azurerm_lb_rule" "externallb_rule" {
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    loadbalancer_id                = "${azurerm_lb.externallb_master.id}"
    name                =   "${format("%s-master-externallb-rule", var.prefix)}"
    protocol                       = "Tcp"
    frontend_port                  = 443
    backend_port                   = 443
    frontend_ip_configuration_name = "masterExternalFrontend"
    backend_address_pool_id = "${azurerm_lb_backend_address_pool.externallb_master.id}"
    probe_id = "${azurerm_lb_probe.lb_probe_masterexternallb.id}"
    depends_on = ["azurerm_lb_probe.lb_probe_masterexternallb"]

    load_distribution = "SourceIPProtocol"
}

resource "azurerm_lb_backend_address_pool" "externallb_master" {
    name                = "${format("%s-master-externallb-backend-pool", var.prefix)}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    loadbalancer_id     = "${azurerm_lb.externallb_master.id}"
}

# internal LB
resource "azurerm_lb" "lb_master" {
    name                = "${format("%s-master-lb", var.prefix)}"
    location           = "${var.location}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    frontend_ip_configuration {
        name                 = "masterfrontend"
        subnet_id = "${data.terraform_remote_state.network.subnet_intsub01_id}"
        private_ip_address = "${var.internallb_masterIP}"
        #private_ip_address = "10.250.0.10"
        private_ip_address_allocation = "Static"
    }
}

resource "azurerm_lb_probe" "lb_probe_masterlb" {
    name                = "${format("%s-master-lb-probe", var.prefix)}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    loadbalancer_id     = "${azurerm_lb.lb_master.id}"
    protocol = "Tcp"
    port                = 443
}

resource "azurerm_lb_rule" "lb_rule_masterlb" {
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    loadbalancer_id                = "${azurerm_lb.lb_master.id}"
    name                =   "${format("%s-master-lb-rule-https", var.prefix)}"
    protocol                       = "Tcp"
    frontend_port                  = 443
    backend_port                   = 443
    frontend_ip_configuration_name = "masterfrontend"
    backend_address_pool_id = "${azurerm_lb_backend_address_pool.masterapi.id}"
    probe_id = "${azurerm_lb_probe.lb_probe_masterlb.id}"
    depends_on = ["azurerm_lb_probe.lb_probe_masterlb"]

    load_distribution = "SourceIPProtocol"
}

resource "azurerm_lb_backend_address_pool" "masterapi" {
    name                = "${format("%s-master-lb-backend-pool", var.prefix)}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    loadbalancer_id     = "${azurerm_lb.lb_master.id}"
}



# 2.7.2 Router Load Balancer
# External LB for router VMs
resource "azurerm_public_ip" "router" {
    name                = "${format("%s-router-lb-pip", var.prefix)}"
    location            = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.resourcegroup.name}"
    public_ip_address_allocation = "static"
    domain_name_label = "${format("%s-router-lb", var.prefix)}"
}

resource "azurerm_lb" "router" {
    name                = "${format("%s-router-lb", var.prefix)}"
    location           = "${var.location}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    frontend_ip_configuration {
        name                 = "routerFrontEnd"
        public_ip_address_id = "${azurerm_public_ip.router.id}"
    }
}

resource "azurerm_lb_probe" "router" {
    name                = "${format("%s-router-lb-probe", var.prefix)}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    loadbalancer_id     = "${azurerm_lb.router.id}"
    protocol = "Tcp"
    port                = 80
}

resource "azurerm_lb_rule" "routerrule" {
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    loadbalancer_id                = "${azurerm_lb.router.id}"
    name                =   "${format("%s-router-lb-rule-http", var.prefix)}"
    protocol                       = "Tcp"
    frontend_port                  = 80
    backend_port                   = 80
    frontend_ip_configuration_name = "routerFrontEnd"
    backend_address_pool_id = "${azurerm_lb_backend_address_pool.router.id}"
    probe_id = "${azurerm_lb_probe.router.id}"
    depends_on = ["azurerm_lb_probe.router"]

    load_distribution = "SourceIPProtocol"
}

resource "azurerm_lb_rule" "httpsrouterrule" {
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    loadbalancer_id                = "${azurerm_lb.router.id}"
    name                =   "${format("%s-router-lb-rule-https", var.prefix)}"
    protocol                       = "Tcp"
    frontend_port                  = 443
    backend_port                   = 443
    frontend_ip_configuration_name = "routerFrontEnd"
    backend_address_pool_id = "${azurerm_lb_backend_address_pool.router.id}"
    probe_id = "${azurerm_lb_probe.router.id}"
    depends_on = ["azurerm_lb_probe.router"]

    load_distribution = "SourceIPProtocol"
}

resource "azurerm_lb_backend_address_pool" "router" {
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    loadbalancer_id     = "${azurerm_lb.router.id}"
    name                = "${format("%s-router-lb-backend-pool", var.prefix)}"
}

#2.8.1 Availability Sets

resource "azurerm_availability_set" "app" {
    name                  = "${format("%s-app-av", var.prefix)}"
    location              = "${var.location}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    platform_update_domain_count = 5 // Korea regions support up to 2 fault domains
    platform_fault_domain_count = 2 // Korea regions support up to 2 fault domains
    managed = true
}

resource "azurerm_availability_set" "infra" {
    name                  = "${format("%s-infra-av", var.prefix)}"
    location              = "${var.location}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    platform_update_domain_count = 5 // Korea regions support up to 2 fault domains
    platform_fault_domain_count = 2 // Korea regions support up to 2 fault domains
 
    managed = true
}

resource "azurerm_availability_set" "router" {
    name                  = "${format("%s-router-av", var.prefix)}"
    location              = "${var.location}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    platform_update_domain_count = 5 // Korea regions support up to 2 fault domains
    platform_fault_domain_count = 2 // Korea regions support up to 2 fault domains
 
    managed = true
}

resource "azurerm_availability_set" "master" {
    name                  = "${format("%s-master-av", var.prefix)}"
    location              = "${var.location}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    platform_update_domain_count = 5 // Korea regions support up to 2 fault domains
    platform_fault_domain_count = 2 // Korea regions support up to 2 fault domains
 
    managed = true
}


#2.8.2 Master Instance Creation
resource "azurerm_network_interface" "master" {
    count = "${var.vmnum_master}"
    
    name                  = "${format("%s-master-%02d-nic", var.prefix, count.index + 1)}"
    location            = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.resourcegroup.name}"

    ip_configuration {
        name = "${join("", list("ipconfig", "0"))}"
        subnet_id = "${data.terraform_remote_state.network.subnet_intsub01_id}"
        private_ip_address_allocation = "static"
        private_ip_address = "${format("10.250.0.%d", count.index + 11)}"
    }

    internal_dns_name_label = "ocp-master-${count.index}"
    network_security_group_id = "${data.terraform_remote_state.network.nsg_master_id}"
    enable_accelerated_networking = "true"
}

resource "azurerm_network_interface_backend_address_pool_association" "master" {
    network_interface_id    = "${element(azurerm_network_interface.master.*.id, count.index)}"
    ip_configuration_name = "${join("", list("ipconfig", "0"))}"
    backend_address_pool_id = "${azurerm_lb_backend_address_pool.masterapi.id}"

    count = "${var.vmnum_master}"
}

resource "azurerm_network_interface_backend_address_pool_association" "externallb_master" {
    network_interface_id    = "${element(azurerm_network_interface.master.*.id, count.index)}"
    ip_configuration_name = "${join("", list("ipconfig", "0"))}"
    backend_address_pool_id = "${azurerm_lb_backend_address_pool.externallb_master.id}"

    count = "${var.vmnum_master}"
}


resource "azurerm_virtual_machine" "master" {
    name                  = "${format("%s-master-%02d", var.prefix, count.index + 1)}"
    location              = "${var.location}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    vm_size               = "${var.vmsize_master}"
    
    count = "${var.vmnum_master}"
 
    availability_set_id = "${azurerm_availability_set.master.id}"

    storage_image_reference {
        id = "${azurerm_image.image.id}"
    }

    storage_os_disk {
        name          = "${format("%s-master-%02d-osdisk", var.prefix, count.index + 1)}"
        caching       = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb = "127"
    }

   
    storage_data_disk {
        name          = "${format("%s-master-%02d-datadisk-0", var.prefix, count.index + 1)}"
        managed_disk_type       = "Standard_LRS"
        create_option = "Empty"
        lun = 0
        disk_size_gb = "512"
    }
    
    os_profile {
        computer_name  = "${format("%s-master-%02d", var.prefix, count.index + 1)}"
        admin_username = "${var.adminUsername}"
        admin_password = "${var.adminPassword}"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    network_interface_ids = ["${element(azurerm_network_interface.master.*.id, count.index)}"]
}


# Infra Instance Creation
resource "azurerm_network_interface" "infra" {
    name                  = "${format("%s-infra-%02d-nic", var.prefix, count.index + 1)}"
    location            = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.resourcegroup.name}"
    
    count = "${var.vmnum_infra}"

    ip_configuration {
        name = "${join("", list("ipconfig", "0"))}"
        subnet_id = "${data.terraform_remote_state.network.subnet_intsub01_id}"
        private_ip_address_allocation = "static"
        private_ip_address = "${format("10.250.0.%d", count.index + 21)}"
    }

    internal_dns_name_label = "ocp-infra-${count.index}"
    network_security_group_id = "${data.terraform_remote_state.network.nsg_infra_id}"
    enable_accelerated_networking = "true"
}

resource "azurerm_virtual_machine" "infra" {
    name                  = "${format("%s-infra-%02d", var.prefix, count.index + 1)}"
    location              = "${var.location}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    vm_size               = "${var.vmsize_infra}"
    
    count = "${var.vmnum_infra}"
 
    availability_set_id = "${azurerm_availability_set.infra.id}"

    storage_image_reference {
        id = "${azurerm_image.image.id}"
    }

    storage_os_disk {
        name          = "${format("%s-infra-%02d-osdisk", var.prefix, count.index + 1)}"
        caching       = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb = "127"
    }

    storage_data_disk {
        name          = "${format("%s-infra-%02d-datadisk", var.prefix, count.index + 1)}"
        managed_disk_type       = "Standard_LRS"
        create_option = "Empty"
        lun = 0
        disk_size_gb = "256"
    }
    
    os_profile {
        computer_name  = "${format("%s-infra-%02d", var.prefix, count.index + 1)}"
        admin_username = "${var.adminUsername}"
        admin_password = "${var.adminPassword}"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    network_interface_ids = ["${element(azurerm_network_interface.infra.*.id, count.index)}"]
}

#2.8.3 Router Instance Creation

resource "azurerm_network_interface" "router" {
    count = "${var.vmnum_router}"
    
    name                = "${format("%s-router-%02d-nic", var.prefix, count.index + 1)}"
    location            = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.resourcegroup.name}"

    ip_configuration {
        name = "${join("", list("ipconfig", "0"))}"
        subnet_id = "${data.terraform_remote_state.network.subnet_extsub01_id}"
        private_ip_address_allocation = "static"
        private_ip_address = "${format("10.250.1.%d", count.index + 11)}"
    }

    internal_dns_name_label = "ocp-router-${count.index}"
    network_security_group_id = "${data.terraform_remote_state.network.nsg_router_id}"
    enable_accelerated_networking = "true"
}

resource "azurerm_network_interface_backend_address_pool_association" "router" {
    network_interface_id    = "${element(azurerm_network_interface.router.*.id, count.index)}"
    ip_configuration_name = "${join("", list("ipconfig", "0"))}"
    backend_address_pool_id = "${azurerm_lb_backend_address_pool.router.id}"

    count = "${var.vmnum_router}"
}

resource "azurerm_virtual_machine" "router" {
    name                  = "${format("%s-router-%02d", var.prefix, count.index + 1)}"
    location              = "${var.location}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    vm_size               = "${var.vmsize_router}"
    
    count = "${var.vmnum_router}"
 
    availability_set_id = "${azurerm_availability_set.router.id}"

    storage_image_reference {
        id = "${azurerm_image.image.id}"
    }

    storage_os_disk {
        name          = "${format("%s-router-%02d-osdisk", var.prefix, count.index + 1)}"
        caching       = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb = "127"
    }
    
    storage_data_disk {
        name          = "${format("%s-router-%02d-datadisk", var.prefix, count.index + 1)}"
        managed_disk_type       = "Standard_LRS"
        create_option = "Empty"
        lun = 0
        disk_size_gb = "256"
    }
    
    os_profile {
        computer_name  = "${format("%s-router-%02d", var.prefix, count.index + 1)}"
        admin_username = "${var.adminUsername}"
        admin_password = "${var.adminPassword}"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    network_interface_ids = ["${element(azurerm_network_interface.router.*.id, count.index)}"]
}

#2.8.4 Application Instance Creation

resource "azurerm_network_interface" "app" {
    name                = "${format("%s-app-%02d-nic", var.prefix, count.index + 1)}"
    location            = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.resourcegroup.name}"
    
    count = "${var.vmnum_app}"

    ip_configuration {
        name = "${join("", list("ipconfig", "0"))}"
        subnet_id = "${data.terraform_remote_state.network.subnet_intsub01_id}"
        private_ip_address_allocation = "static"
        private_ip_address = "${format("10.250.0.%d", count.index + 31)}"
    }

    internal_dns_name_label = "ocp-app-${count.index}"
    network_security_group_id = "${data.terraform_remote_state.network.nsg_app_id}"
    enable_accelerated_networking = "true"
}

resource "azurerm_virtual_machine" "app" {
    name                  = "${format("%s-app-%02d", var.prefix, count.index + 1)}"
    location              = "${var.location}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    vm_size               = "${var.vmsize_app}"
    
    count = "${var.vmnum_app}"
 
    availability_set_id = "${azurerm_availability_set.app.id}"

    storage_image_reference {
        id = "${azurerm_image.image.id}"
    }

    storage_os_disk {
        name          = "${format("%s-app-%02d-osdisk", var.prefix, count.index + 1)}"
        caching       = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb = "127"
    }
   
    storage_data_disk {
        name          = "${format("%s-app-%02d-datadisk", var.prefix, count.index + 1)}"
        managed_disk_type       = "Standard_LRS"
        create_option = "Empty"
        lun = 0
        disk_size_gb = "256"
    }
 
    os_profile {
        computer_name  = "${format("%s-app-%02d", var.prefix, count.index + 1)}"
        admin_username = "${var.adminUsername}"
        admin_password = "${var.adminPassword}"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    network_interface_ids = ["${element(azurerm_network_interface.app.*.id, count.index)}"]
}

#2.8.6 Deploying the Bastion Instance

resource "azurerm_public_ip" "bastion" {
    name                  = "${format("%s-bastion-pip", var.prefix)}"
    location            = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.resourcegroup.name}"
    public_ip_address_allocation = "static"
    domain_name_label = "${format("%s-bastion", var.prefix)}"
}

resource "azurerm_network_interface" "bastion" {
    name                = "${format("%s-bastion-nic", var.prefix)}"
    location            = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.resourcegroup.name}"

    ip_configuration {
        name = "${join("", list("ipconfig", "0"))}"
        subnet_id = "${data.terraform_remote_state.network.subnet_dmzsub01_id}"
        private_ip_address_allocation = "static"
        private_ip_address = "${var.bastion_private_IP}"
        public_ip_address_id = "${azurerm_public_ip.bastion.id}"
    }

    network_security_group_id = "${data.terraform_remote_state.network.nsg_bastion_id}"
    enable_accelerated_networking = "true"
}


resource "azurerm_virtual_machine" "bastion" {
    name                  = "${format("%s-bastion", var.prefix)}"
    location              = "${var.location}"
    resource_group_name  =  "${azurerm_resource_group.resourcegroup.name}"
    vm_size               = "${var.vmsize_bastion}"

    storage_image_reference {
        id = "${azurerm_image.image.id}"
    }

    storage_os_disk {
        name          = "${format("%s-bastion-osdisk", var.prefix)}"
        caching       = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb = "127"
    }

    os_profile {
        computer_name  = "${format("%s-bastion", var.prefix)}"
        admin_username = "${var.adminUsername}"
        admin_password = "${var.adminPassword}"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    storage_data_disk {
        name          = "${format("%s-bastion-datadisk", var.prefix)}"
        managed_disk_type       = "Standard_LRS"
        create_option = "Empty"
        lun = 0
        disk_size_gb = "256"
    }

    network_interface_ids = ["${azurerm_network_interface.bastion.id}"]
}

output "routerLB_public_ip_address" {
      value = "${azurerm_public_ip.router.ip_address}"
}

output "bastion_public_ip_address" {
      value = "${azurerm_public_ip.bastion.ip_address}"
}

output "master_public_ip_address" {
      value = "${azurerm_public_ip.pip_masterexternallb.ip_address}"
}

output "router_network_interface_ids" {
    value = ["${azurerm_network_interface.router.*.id}"]
}

output "rhel75_image_id" {
    value = "${azurerm_image.image.id}"
}

output "app_avset_id" {
    value = "${azurerm_availability_set.app.id}"
}


