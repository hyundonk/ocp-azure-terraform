# Terraform script for openshift 2018.11.11
# terraform plan -var-file=<variable path/filename> -out=<destination filename>
# Configure the Microsoft Azure Provider
# resource group for network resources
# virtual network
# subnets
# NSGs
# VPN GW
# VPN connections 

variable "location" {}
variable "subscription_id" {}

variable "tfbackend_storageaccount" {}

variable "resourcegroup_name_network" {}
variable "internallb_masterIP" {}
variable "internallb_routerIP" {}
 
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
	key="ddp/network.tfstate"
  }
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "network" {
  name     = "${var.resourcegroup_name_network}"
  location = "${var.location}"
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "ddpprodnet"
  address_space       = ["10.250.0.0/21"]
  location = "${var.location}"
  resource_group_name = "${azurerm_resource_group.network.name}"
}

# Firewall Segment subnet for vnet gateway connection

resource "azurerm_subnet" "intsub01" {
    name                 = "ddp-intsub01"
    resource_group_name  = "${azurerm_resource_group.network.name}"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"
    address_prefix       = "10.250.0.0/24"
    #network_security_group_id = "${azurerm_network_security_group.nsg-intsub01.id}"
    
    depends_on = ["azurerm_virtual_network.vnet"]
}

resource "azurerm_subnet" "intsub02" {
    name                 = "ddp-intsub02"
    resource_group_name  = "${azurerm_resource_group.network.name}"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"
    address_prefix       = "10.250.3.0/24"
    #network_security_group_id = "${azurerm_network_security_group.nsg-intsub01.id}"
}

resource "azurerm_subnet" "extsub01" {
    name                 = "ddp-extsub01"
    resource_group_name  = "${azurerm_resource_group.network.name}"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"
    address_prefix       = "10.250.1.0/24"
    #network_security_group_id = "${azurerm_network_security_group.nsg-extsub01.id}"
}

# Gateway subnet for vnet gateway connection
resource "azurerm_subnet" "GatewaySubnet" {
    name                 = "GatewaySubnet"
    resource_group_name  = "${azurerm_resource_group.network.name}"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"
    address_prefix       = "10.250.7.0/27"
}

resource "azurerm_subnet" "dmzsub01" {
    name                      = "ddp-dmzsub01"
    resource_group_name       = "${azurerm_resource_group.network.name}"
    virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
    address_prefix       = "10.250.2.0/24"
}

# Network Security Groups
#  bastion-nsg
#  master-nsg
#  infra-node-nsg
#  node-nsg
#  cns-nsg

resource "azurerm_network_security_group" "nsg-bastion" {
    name                = "ddp-bastion-nsg"
    location            = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.network.name}"
     
    security_rule {
        name                       = "bastion-nsg-ssh"
        priority                   = 500
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        description = "SSH access from Internet"
    }
}

resource "azurerm_network_security_group" "nsg-master" {
    name                = "ddp-master-nsg"
    location            = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.network.name}"
     
    security_rule {
        name                       = "master-ssh"
        priority                   = 500
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "*"
        description = "SSH from the bastion"
    }

    security_rule {
        name                       = "master-etcd"
        priority                   = 525
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "VirtualNetwork"
        source_port_range          = "*"
        destination_port_ranges     = ["2379", "2380"]
        destination_address_prefix = "*"
        description = "ETCD service ports"
    }

    security_rule {
        name                       = "master-api"
        priority                   = 550
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "*"
        source_port_range          = "*"
        destination_port_range     = "443"
        destination_address_prefix = "*"
        description = "API port"
    }

    security_rule {
        name                       = "master-api-lb"
        priority                   = 575
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "VirtualNetwork"
        source_port_range          = "*"
        destination_port_range     = "443"
        destination_address_prefix = "*"
        description = "API port"
    }

    security_rule {
        name                       = "master-ocp-tcp"
        priority                   = 600
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "VirtualNetwork"
        source_port_range          = "*"
        destination_port_range     = "8053"
        destination_address_prefix = "*"
        description = "TCP DNS and fluentd"
    }

    security_rule {
        name                       = "master-ocp-udp"
        priority                   = 625
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Udp"
        source_address_prefix      = "VirtualNetwork"
        source_port_range          = "*"
        destination_port_range     = "8053"
        destination_address_prefix = "*"
        description = "UDP DNS and fluentd"
    }

    security_rule {
        name                       = "node-kubelet"
        priority                   = 650
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "VirtualNetwork"
        source_port_range          = "*"
        destination_port_range     = "10250"
        destination_address_prefix = "*"
        description = "kubelet"
    }

    security_rule {
        name                       = "node-sdn"
        priority                   = 675
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Udp"
        source_address_prefix      = "VirtualNetwork"
        source_port_range          = "*"
        destination_port_range     = "4789"
        destination_address_prefix = "*"
        description = "OpenShift sdn"
    }


}

resource "azurerm_network_security_group" "nsg-infra" {
    name                = "ddp-infra-nsg"
    location            = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.network.name}"
     
    security_rule {
        name                       = "infra-ssh"
        priority                   = 500
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "*"
        description = "SSH from the bastion"
    }

    security_rule {
        name                       = "infra-ports"
        priority                   = 550
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "VirtualNetwork"
        source_port_range          = "*"
        destination_port_ranges     = ["9200", "9300"]
        destination_address_prefix = "*"
        description = "ElasticSearch"
    }

    security_rule {
        name                       = "node-kubelet"
        priority                   = 575
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "VirtualNetwork"
        source_port_range          = "*"
        destination_port_range     = "10250"
        destination_address_prefix = "*"
        description = "kubelet"
    }

    security_rule {
        name                       = "node-sdn"
        priority                   = 600
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Udp"
        source_address_prefix      = "VirtualNetwork"
        source_port_range          = "*"
        destination_port_range     = "4789"
        destination_address_prefix = "*"
        description = "OpenShift sdn"
    }

}


resource "azurerm_network_security_group" "nsg-router" {
    name                = "ddp-router-nsg"
    location            = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.network.name}"
     
    security_rule {
        name                       = "router-ssh"
        priority                   = 500
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "*"
        description = "SSH from the bastion"
    }

    security_rule {
        name                       = "router-ports"
        priority                   = 525
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "AzureLoadBalancer"
        source_port_range          = "*"
        destination_port_ranges     = ["80", "443"]
        destination_address_prefix = "*"
        description = "OpenShift router"
    }

    security_rule {
        name                       = "node-kubelet"
        priority                   = 575
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "VirtualNetwork"
        source_port_range          = "*"
        destination_port_range     = "10250"
        destination_address_prefix = "*"
        description = "kubelet"
    }

    security_rule {
        name                       = "node-sdn"
        priority                   = 600
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Udp"
        source_address_prefix      = "VirtualNetwork"
        source_port_range          = "*"
        destination_port_range     = "4789"
        destination_address_prefix = "*"
        description = "OpenShift sdn"
    }

    security_rule {
        name                       = "router-ports2"
        priority                   = 625
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "*"
        source_port_range          = "*"
        destination_port_ranges     = ["80", "443"]
        destination_address_prefix = "*"
        description = "OpenShift router"
    }

}

resource "azurerm_network_security_group" "nsg-app" {
    name                = "ddp-app-nsg"
    location            = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.network.name}"
     
    security_rule {
        name                       = "node-ssh"
        priority                   = 500
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "*"
        description = "SSH from the bastion"
    }

    security_rule {
        name                       = "node-kubelet"
        priority                   = 525
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "VirtualNetwork"
        source_port_range          = "*"
        destination_port_range     = "10250"
        destination_address_prefix = "*"
        description = "kubelet"
    }

    security_rule {
        name                       = "node-sdn"
        priority                   = 550
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Udp"
        source_address_prefix      = "VirtualNetwork"
        source_port_range          = "*"
        destination_port_range     = "4789"
        destination_address_prefix = "*"
        description = "ElasticSearch and ocp apps"
    }

    security_rule {
        name                       = "node-lbcheck"
        priority                   = 575
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "VirtualNetwork"
        source_port_range          = "*"
        destination_port_range     = "10256"
        destination_address_prefix = "*"
        description = "Load Balancer health check"
    }
}

resource "azurerm_network_security_group" "nsg-sqlmi" {
    name                = "ddp-sqlml-nsg"
    location            = "${var.location}"
    resource_group_name  = "${azurerm_resource_group.network.name}"
     
    security_rule {
        name                       = "management_incoming"
        priority                   = 500
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        source_address_prefix      = "*"
        destination_port_ranges    = [9000, 9003, 1438, 1440, 1452]
        destination_address_prefix = "*"
        description = "inbound port for management"
    }

    security_rule {
        name                       = "mi_subnet_in"
        priority                   = 525
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "10.250.3.0/24"
        destination_address_prefix = "*"
        description = "Allow all from MI SUBNET"
    }

    security_rule {
        name                       = "health_probe"
        priority                   = 550
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "AzureLoadBalancer"
        destination_address_prefix = "*"
        description = "Health_probe"
    }

    security_rule {
        name                       = "deny_others"
        priority                   = 575
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        description = "Deny others"
    }


    security_rule {
        name                       = "management_outgoing"
        priority                   = 575
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "TCP"
        source_port_range          = "*"
        source_address_prefix      = "*"
        destination_port_ranges     = [80, 443, 12000]
        destination_address_prefix = "*"
        description = "management for  outgoing"
    }

    security_rule {
        name                       = "mi_subnet_out"
        priority                   = 600
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        source_address_prefix      = "*"
        destination_port_range    = "*"
        destination_address_prefix = "10.250.3.0/24"
        description = "management for  outgoing"
    }

    security_rule {
        name                       = "deny_all"
        priority                   = 700
        direction                  = "Outbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        source_address_prefix      = "*"
        destination_port_range    = "*"
        destination_address_prefix = "*"
        description = "Deny for other outoing"
    }

}

resource "azurerm_dns_zone" "private_zone" {
    name = "d-platform.doosan.com"
    resource_group_name  = "${azurerm_resource_group.network.name}"
    zone_type = "Private"
    #registration_virtual_network_ids = ["${azurerm_virtual_network.vnet.id}"]
    resolution_virtual_network_ids = ["${azurerm_virtual_network.vnet.id}"]
}

resource "azurerm_dns_a_record" "master" {
    zone_name = "${azurerm_dns_zone.private_zone.name}"
    name                = "ddp-master-lb"
    resource_group_name  = "${azurerm_resource_group.network.name}"
    ttl                 = 300
    records = ["${var.internallb_masterIP}"]
}

resource "azurerm_dns_a_record" "apig" {
    name                = "*.apig"
    zone_name = "${azurerm_dns_zone.private_zone.name}"
    resource_group_name  =  "${azurerm_resource_group.network.name}"
    ttl                 = 300
    records             = ["${var.internallb_routerIP}"]
}

resource "azurerm_dns_a_record" "apps" {
    name                = "*.apps"
    zone_name = "${azurerm_dns_zone.private_zone.name}"
    resource_group_name  =  "${azurerm_resource_group.network.name}"
    ttl                 = 300
    records             = ["${var.internallb_routerIP}"]
}

resource "azurerm_dns_a_record" "git" {     #for application logs
    name                = "git"
    zone_name = "${azurerm_dns_zone.private_zone.name}"
    resource_group_name  =  "${azurerm_resource_group.network.name}"
    ttl                 = 300
    records             = ["${var.internallb_routerIP}"]
}

resource "azurerm_dns_a_record" "logs" {     #for application logs
    name                = "logs"
    zone_name = "${azurerm_dns_zone.private_zone.name}"
    resource_group_name  =  "${azurerm_resource_group.network.name}"
    ttl                 = 300
    records             = ["${var.internallb_routerIP}"]
}

resource "azurerm_dns_a_record" "registry" {       #for future istio integration
    name                = "registry"
    zone_name = "${azurerm_dns_zone.private_zone.name}"
    resource_group_name  =  "${azurerm_resource_group.network.name}"
    ttl                 = 300
    records             = ["${var.internallb_routerIP}"]
}

resource "azurerm_dns_a_record" "registry_console" {       #for future istio integration
    name                = "console.registry"
    zone_name = "${azurerm_dns_zone.private_zone.name}"
    resource_group_name  =  "${azurerm_resource_group.network.name}"
    ttl                 = 300
    records             = ["${var.internallb_routerIP}"]
}


# This makes possible that virtual machine import subnet information
output "vnet_name" {
      value = "${azurerm_virtual_network.vnet.name}"
}

output "subnet_intsub01_id" {
      value = "${azurerm_subnet.intsub01.id}"
}

output "subnet_extsub01_id" {
      value = "${azurerm_subnet.extsub01.id}"
}

output "subnet_dmzsub01_id" {
      #value = "${data.azurerm_subnet.dmzsub01.id}"
      value = "${azurerm_subnet.dmzsub01.id}"
}

output "subnet_gatewaysubnet_id" {
      value = "${azurerm_subnet.GatewaySubnet.id}"
}

output "nsg_bastion_id" {
      value = "${azurerm_network_security_group.nsg-bastion.id}"
}

output "nsg_master_id" {
      value = "${azurerm_network_security_group.nsg-master.id}"
}

output "nsg_router_id" {
      value = "${azurerm_network_security_group.nsg-router.id}"
}

output "nsg_infra_id" {
      value = "${azurerm_network_security_group.nsg-infra.id}"
}

output "nsg_app_id" {
      value = "${azurerm_network_security_group.nsg-app.id}"
}

output "vnet_id" {
      value = "${azurerm_virtual_network.vnet.id}"
}

output "network_resourcegroup_name" {
      value = "${azurerm_resource_group.network.name}"
}


