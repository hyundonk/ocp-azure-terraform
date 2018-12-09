variable "location" {}
variable "subscription_id" {}

variable "tfbackend_storageaccount" {}

variable "internallb_masterIP" {}
variable "internallb_routerIP" {}
 
variable "resourcegroup_name_network" {}
variable "resourcegroup_name_cluster" {}

module "network" {
    source = "./network"
    location = "${var.location}"
    subscription_id = "${var.subscription_id}"

    internallb_masterIP = "${var.internallb_masterIP}"
    internallb_routerIP = "${var.internallb_routerIP}"

    tfbackend_storageaccount = "${var.tfbackend_storageaccount}"
    resourcegroup_name_network = "${var.resourcegroup_name_network}"
}

variable "image_path" {} # URL for RHEL7.5 OS disk image (vhd)

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

module "ocpcluster" {
    source = "./ocpcluster"

    location = "${var.location}"
    subscription_id = "${var.subscription_id}"
    
    tfbackend_storageaccount = "${var.tfbackend_storageaccount}"
   
    resourcegroup_name_cluster = "${var.resourcegroup_name_cluster}"

    image_path = "${var.image_path}"

    internallb_masterIP = "${var.internallb_masterIP}"
    internallb_routerIP = "${var.internallb_routerIP}"
 
    prefix = "${var.prefix}"

    vmsize_master = "${var.vmsize_master}"
    vmsize_infra = "${var.vmsize_infra}"
    vmsize_router = "${var.vmsize_router}"
    vmsize_app = "${var.vmsize_app}"
    vmsize_bastion = "${var.vmsize_bastion}"


    vmnum_master = "${var.vmnum_master}"
    vmnum_infra = "${var.vmnum_infra}"
    vmnum_router = "${var.vmnum_router}"
    vmnum_app = "${var.vmnum_app}"

    adminUsername = "${var.adminUsername}"
    adminPassword = "${var.adminPassword}"
    
    access_key = "${var.access_key}"
    
    bastion_private_IP = "${var.bastion_private_IP}"
}

variable "dnszone_name" {}

module "dnszone" {
    source = "./dnszone"
    
    location = "${var.location}"
    subscription_id = "${var.subscription_id}"
    
    tfbackend_storageaccount = "${var.tfbackend_storageaccount}"

    access_key = "${var.access_key}"

    dnszone_name = "${var.dnszone_name}"
}

variable "shared_key" {}
variable "address_space_SZDC" {type = "list"}
variable "gateway_address_SZDC" {}

module "vpn" {
    source = "./vpn"
   
    location = "${var.location}"
    subscription_id = "${var.subscription_id}"
    
    tfbackend_storageaccount = "${var.tfbackend_storageaccount}"
    prefix = "${var.prefix}"

    shared_key = "${var.shared_key}"
    access_key = "${var.access_key}"

    address_space_SZDC = "${var.address_space_SZDC}"
    gateway_address_SZDC = "${var.gateway_address_SZDC}"
}

module "routerinternallb" {
    source = "./routerinternallb"
   
    location = "${var.location}"
    subscription_id = "${var.subscription_id}"
    
    tfbackend_storageaccount = "${var.tfbackend_storageaccount}"
    access_key = "${var.access_key}"
    
    resourcegroup_name_cluster = "${var.resourcegroup_name_cluster}"
    
    prefix = "${var.prefix}"

    vmnum_router = "${var.vmnum_router}"
    
    internallb_routerIP = "${var.internallb_routerIP}"
}

