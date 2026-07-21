
resource "azurerm_virtual_network" "virtual-network" {
  name                = "virtual-network"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  address_space       = ["10.5.0.0/16"]
}

resource "azurerm_subnet" "public_subnet_a" {
  name                 = "public_subnet_a"
  resource_group_name  = data.azurerm_resource_group.azure-resource.name
  virtual_network_name = azurerm_virtual_network.virtual-network.name
  address_prefixes     = ["10.5.0.0/24"]
}

resource "azurerm_subnet" "public_subnet_b" {
  name                 = "public_subnet_b"
  resource_group_name  = data.azurerm_resource_group.azure-resource.name
  virtual_network_name = azurerm_virtual_network.virtual-network.name
  address_prefixes     = ["10.5.1.0/24"]
}

resource "azurerm_public_ip" "public-ip-quotes" {
  name                = "public-ip-quotes"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = azurerm_virtual_network.virtual-network.location
  allocation_method   = "Dynamic"
}

resource "azurerm_public_ip" "public-ip-newsfeed" {
  name                = "public-ip-newsfeed"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = azurerm_virtual_network.virtual-network.location
  allocation_method   = "Dynamic"
}

resource "azurerm_public_ip" "public-ip-frontend" {
  name                = "public-ip-frontend"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = azurerm_virtual_network.virtual-network.location
  allocation_method   = "Dynamic"
}

# Routing table for public subnets
resource "azurerm_route_table" "route-table" {
  name                          = "route-table"
  location                      = azurerm_virtual_network.virtual-network.location
  resource_group_name           = azurerm_virtual_network.virtual-network.resource_group_name
  disable_bgp_route_propagation = false

  route {
    name           = "route"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }

  tags = {
    environment = "Production"
  }
}

# Associate the routing table to public subnet A
resource "azurerm_subnet_route_table_association" "association-subnet-a" {
  subnet_id      = azurerm_subnet.public_subnet_a.id
  route_table_id = azurerm_route_table.route-table.id
}

# Associate the routing table to public subnet B
resource "azurerm_subnet_route_table_association" "association-subnet-b" {
  subnet_id      = azurerm_subnet.public_subnet_b.id
  route_table_id = azurerm_route_table.route-table.id
}

resource "azurerm_network_security_group" "security-group-quotes" {
  name                = "security-group-quotes"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name
}

resource "azurerm_network_security_group" "security-group-newsfeed" {
  name                = "security-group-newsfeed"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name
}

resource "azurerm_network_security_group" "security-group-frontend" {
  name                = "security-group-frontend"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name
}

resource "azurerm_network_security_rule" "rule-outbound-quotes" {
  name                        = "rule-outbound-quotes"
  priority                    = 1000
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.azure-resource.name
  network_security_group_name = azurerm_network_security_group.security-group-quotes.name
}

resource "azurerm_network_security_rule" "rule-outbound-newsfeed" {
  name                        = "rule-outbound-newsfeed"
  priority                    = 1001
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.azure-resource.name
  network_security_group_name = azurerm_network_security_group.security-group-newsfeed.name
}

resource "azurerm_network_security_rule" "rule-outbound-frontend" {
  name                        = "rule-outbound-frontend"
  priority                    = 1002
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.azure-resource.name
  network_security_group_name = azurerm_network_security_group.security-group-frontend.name
}

resource "azurerm_network_security_rule" "rule-inbound-ssh-quotes" {
  name                        = "rule-inbound-ssh-quotes"
  priority                    = 1003
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = data.azurerm_resource_group.azure-resource.name
  network_security_group_name = azurerm_network_security_group.security-group-quotes.name
}

resource "azurerm_network_security_rule" "rule-inbound-ssh-newsfeed" {
  name                        = "rule-inbound-ssh-newsfeed"
  priority                    = 1004
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = data.azurerm_resource_group.azure-resource.name
  network_security_group_name = azurerm_network_security_group.security-group-newsfeed.name
}

resource "azurerm_network_security_rule" "rule-inbound-ssh-frontend" {
  name                        = "rule-inbound-ssh"
  priority                    = 1005
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = data.azurerm_resource_group.azure-resource.name
  network_security_group_name = azurerm_network_security_group.security-group-frontend.name
}

resource "azurerm_network_security_rule" "rule-inbound-quotes-8082" {
  name                        = "rule-inbound-quotes-8082"
  priority                    = 1006
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8082"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.azure-resource.name
  network_security_group_name = azurerm_network_security_group.security-group-quotes.name
}

resource "azurerm_network_security_rule" "rule-inbound-newsfeed-8081" {
  name                        = "rule-inbound-newsfeed-8081"
  priority                    = 1007
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8081"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.azure-resource.name
  network_security_group_name = azurerm_network_security_group.security-group-newsfeed.name
}

resource "azurerm_network_security_rule" "rule-inbound-frontend-8080" {
  name                        = "rule-inbound-frontend-8080"
  priority                    = 1008
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.azure-resource.name
  network_security_group_name = azurerm_network_security_group.security-group-frontend.name
}

resource "azurerm_network_interface" "network-interface-quotes" {
  name                = "network-interface-quotes"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet_a.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public-ip-quotes.id
  }
}

resource "azurerm_network_interface" "network-interface-newsfeed" {
  name                = "network-interface-newsfeed"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet_a.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public-ip-newsfeed.id
  }
}

resource "azurerm_network_interface" "network-interface-frontend" {
  name                = "network-interface-frontend"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet_b.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public-ip-frontend.id
  }
}

resource "azurerm_network_interface_security_group_association" "association-ni-sg-quotes" {
  network_interface_id      = azurerm_network_interface.network-interface-quotes.id
  network_security_group_id = azurerm_network_security_group.security-group-quotes.id
}

resource "azurerm_network_interface_security_group_association" "association-ni-sg-newsfeed" {
  network_interface_id      = azurerm_network_interface.network-interface-newsfeed.id
  network_security_group_id = azurerm_network_security_group.security-group-newsfeed.id
}

resource "azurerm_network_interface_security_group_association" "association-ni-sg-frontend" {
  network_interface_id      = azurerm_network_interface.network-interface-frontend.id
  network_security_group_id = azurerm_network_security_group.security-group-frontend.id
}
