###################################################################################
# Terraform script for adding application gateway 2019.01.16

variable "location" {}
variable "subscription_id" {}

variable "tfbackend_storageaccount" {}

variable "resourcegroup_name_cluster" {}
 
variable "prefix" {}

variable "access_key" {}

variable "appgw_site1_hostname" {}

variable "appgw_backend_address_pool_ip_address_list" {
    type = "list"
}

variable "appgw_site1_ssl_cert_password" {}

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
        key                     = "ddp/appgateway.tfstate"
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

# Create Application Gateway

resource "azurerm_public_ip" "pip_appgw" {
    name                  = "${format("%s-appgw-pip", var.prefix)}"
    location            = "${var.location}"
    resource_group_name  = "${var.resourcegroup_name_cluster}"
    allocation_method = "Dynamic"
}


resource "azurerm_application_gateway" "appgw" {
    name                = "${format("%s-appgw", var.prefix)}"
    resource_group_name  = "${var.resourcegroup_name_cluster}"
    location            = "${var.location}"
    sku {
        name     = "WAF_Medium"
        tier     = "WAF"
        capacity = 2
    }

    gateway_ip_configuration {
	    name = "appGatewayIpConfig" 
        subnet_id = "${data.terraform_remote_state.network.subnet_appgwsubnet_id}"
    }  

    frontend_port {
	    name = "appGatewayFrontendPort" 
	    port = "443" 
    }

    frontend_ip_configuration {
	    name = "appGatewayFrontendIP" 
	    private_ip_address_allocation  = "Dynamic" 
        public_ip_address_id = "${azurerm_public_ip.pip_appgw.id}"
    }

    backend_address_pool {
	    name = "appGatewayBackendPool" 
        ip_address_list = "${var.appgw_backend_address_pool_ip_address_list}"
    }

    backend_http_settings {
	    name = "appGatewayBackendHttpSettings" 
        port                  = 80
        protocol              = "Http"
        cookie_based_affinity = "Disabled"
	    request_timeout = "30" 
        probe_name            = "${format("probe-%s", var.appgw_site1_hostname)}"
    }

    http_listener {
	    name = "appGatewayHttpListener" 
	    frontend_ip_configuration_name = "appGatewayFrontendIP" 
	    frontend_port_name = "appGatewayFrontendPort" 
	    protocol = "Https" 
        ssl_certificate_name = "${var.appgw_site1_hostname}"
	    require_sni = "false" 
    }

    request_routing_rule {
	    name = "rule1" 
        rule_type                  = "Basic"
	    http_listener_name = "appGatewayHttpListener" 
	    backend_address_pool_name = "appGatewayBackendPool" 
	    backend_http_settings_name = "appGatewayBackendHttpSettings" 
    }

    ssl_certificate {
            name = "${var.appgw_site1_hostname}"
            #data = "${base64encode(file("${format("./WILD.%s.pfx", var.appgw_site1_hostname)}"))}"
            data = "${base64encode(file("appgwcert.pfx"))}"
            password = "${var.appgw_site1_ssl_cert_password}"
    }

    waf_configuration {
        enabled          = "true"
        firewall_mode    = "Detection"
        rule_set_type    = "OWASP"
        rule_set_version = "3.0"
    }
    
    probe {
        name            = "${format("probe-%s", var.appgw_site1_hostname)}"
        protocol            = "http"
        path                = "/"
        host                = "${format("www.%s", var.appgw_site1_hostname)}"
        interval            = "30"
        timeout             = "30"
        unhealthy_threshold = "3"
    }
}

