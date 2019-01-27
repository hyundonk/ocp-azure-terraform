###################################################################################
# Terraform script for adding application gateway 2019.01.16

variable "location" {}
variable "subscription_id" {}

variable "tfbackend_storageaccount" {}

variable "resourcegroup_name_cluster" {}
 
variable "prefix" {}

variable "access_key" {}

variable "vmnum_router" {}

variable "appgw_site1_hostname" {}

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
	    name = "appGatewayFrontendPortHttps" 
	    port = "443" 
    }

    frontend_port {
	    name = "appGatewayFrontendPortHttp" 
	    port = "80" 
    }


    frontend_ip_configuration {
	    name = "doosan-iv-frontendip" 
	    private_ip_address_allocation  = "Dynamic" 
        subnet_id = "${data.terraform_remote_state.network.subnet_appgwsubnet_id}"
#       public_ip_address_id = "${azurerm_public_ip.pip_appgw.id}"
    }

    backend_address_pool {
	    name = "doosan-iv-https-listener-pool" 
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
	    name = "doosan-iv-https-listener" 
	    frontend_ip_configuration_name = "doosan-iv-frontendip" 
	    frontend_port_name = "appGatewayFrontendPortHttps" 
	    protocol = "Https" 
        ssl_certificate_name = "${var.appgw_site1_hostname}"
	    require_sni = "false" 
        host_name = "os-dev.doosan-iv.com"
    }

    http_listener {
	    name = "doosan-iv-http-listener" 
	    frontend_ip_configuration_name = "doosan-iv-frontendip" 
	    frontend_port_name = "appGatewayFrontendPortHttp" 
	    protocol = "Http" 
        host_name = "os-dev.doosan-iv.com"
    }

    request_routing_rule {
	    name = "ruleHttps" 
        rule_type                  = "Basic"
	    http_listener_name = "doosan-iv-https-listener" 
	    backend_address_pool_name = "doosan-iv-https-listener-pool" 
	    backend_http_settings_name = "appGatewayBackendHttpSettings" 
    }

    request_routing_rule {
	    name = "ruleHttp" 
        rule_type                  = "Basic"
	    http_listener_name = "doosan-iv-http-listener" 
	    backend_address_pool_name = "doosan-iv-https-listener-pool" 
	    backend_http_settings_name = "appGatewayBackendHttpSettings" 
    }


    ssl_certificate {
            name = "${var.appgw_site1_hostname}"
            data = "${base64encode(file("${format("./WILD.%s.pfx", var.appgw_site1_hostname)}"))}"
            #data = "${base64encode(file("appgwcert.pfx"))}"
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
        host                = "os-dev.doosan-iv.com"
        #host                = "${format("www.%s", var.appgw_site1_hostname)}"
        interval            = "30"
        timeout             = "30"
        unhealthy_threshold = "3"
    }
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "master" {
    network_interface_id    = "${data.terraform_remote_state.cluster.router_network_interface_ids[count.index]}"
    ip_configuration_name = "${join("", list("ipconfig", "0"))}"
    backend_address_pool_id = "${azurerm_application_gateway.appgw.backend_address_pool.0.id}"

    count = "${var.vmnum_router}"
}


