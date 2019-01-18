
variable "cocktail_vnet_id" {}

resource "azurerm_virtual_network_peering" "vnetpeering" {
    name = "peer2cocktail-vnet"
    resource_group_name = "${azurerm_resource_group.network.name}"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"

    remote_virtual_network_id = "${var.cocktail_vnet_id}"

    allow_virtual_network_access = false
    allow_forwarded_traffic = false
    allow_gateway_transit = true
    use_remote_gateways = false
}
