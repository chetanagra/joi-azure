
resource "azurerm_virtual_network" "virtual-network" {
  name                = "virtual-network"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  address_space       = ["10.5.0.0/16"]
}

resource "azurerm_subnet" "public_subnet" {
  name                 = "public_subnet"
  resource_group_name  = data.azurerm_resource_group.azure-resource.name
  virtual_network_name = azurerm_virtual_network.virtual-network.name
  address_prefixes     = ["10.5.0.0/24"]
}


#Use private subnet for newsfeed and quotes as they don't need to be publically accessiable 
resource "azurerm_subnet" "private_subnet" {
  name                 = "private_subnet"
  resource_group_name  = data.azurerm_resource_group.azure-resource.name
  virtual_network_name = azurerm_virtual_network.virtual-network.name
  address_prefixes     = ["10.5.1.0/24"]
}

#Create NAT gateway
resource "azurerm_nat_gateway" "nat-gateway" {
  name                = "nat-gateway"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  sku_name            = "Standard"
}

# Create public IP for NAT gateway
resource "azurerm_public_ip" "nat-public-ip" {
  name                = "nat-public-ip"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Attach public ip to NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "nat-ip-assoc" {
  nat_gateway_id       = azurerm_nat_gateway.nat-gateway.id
  public_ip_address_id = azurerm_public_ip.nat-public-ip.id
}

# Attach the NAT Gateway to the private subnet
resource "azurerm_subnet_nat_gateway_association" "private-subnet-nat" {
  subnet_id      = azurerm_subnet.private_subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat-gateway.id
}


resource "azurerm_public_ip" "public-ip-frontend" {
  name                = "public-ip-frontend"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = azurerm_virtual_network.virtual-network.location
  allocation_method   = "Dynamic"
}

# Routing table for public subnet
resource "azurerm_route_table" "pub-route-table" {
  name                          = "pub-route-table"
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

# Routing table for private subnet
resource "azurerm_route_table" "pvt-route-table" {
  name                          = "pvt-route-table"
  location                      = azurerm_virtual_network.virtual-network.location
  resource_group_name           = azurerm_virtual_network.virtual-network.resource_group_name
  disable_bgp_route_propagation = false

  tags = {
    environment = "Production"
  }
}

# Associate the routing table to public subnet
resource "azurerm_subnet_route_table_association" "association-subnet-pub" {
  subnet_id      = azurerm_subnet.public_subnet.id
  route_table_id = azurerm_route_table.pub-route-table.id
}


# Associate the routing table to private subnet
resource "azurerm_subnet_route_table_association" "association-subnet-pvt" {
  subnet_id      = azurerm_subnet.private_subnet.id
  route_table_id = azurerm_route_table.pvt-route-table.id
}
*/


resource "azurerm_network_security_group" "security-group-backend" {
  name                = "security-group-backend"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name
}


resource "azurerm_network_security_group" "security-group-frontend" {
  name                = "security-group-frontend"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name
}

resource "azurerm_network_security_rule" "rule-outbound-backend" {
  name                        = "rule-outbound-backend"
  priority                    = 1000
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.azure-resource.name
  network_security_group_name = azurerm_network_security_group.security-group-backend.name
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

resource "azurerm_network_security_rule" "rule-inbound-ssh-backend" {
  name                        = "rule-inbound-ssh-backend"
  priority                    = 1003
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = data.azurerm_resource_group.azure-resource.name
  network_security_group_name = azurerm_network_security_group.security-group-backend.name
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

resource "azurerm_network_security_rule" "rule-inbound-backend" {
  name                        = "rule-inbound-backend"
  priority                    = 1006
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8082,8081"
  source_address_prefix       = "VirtualNetwork" # Allow requests only from within vnet 
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.azure-resource.name
  network_security_group_name = azurerm_network_security_group.security-group-backend.name
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


# NIC for newsfeed and quotes
resource "azurerm_network_interface" "network-interface-backend" {
  name                = "network-interface-backend"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private_subnet.id   # ← changed
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id removed — backend has no public IP
  }
}


resource "azurerm_network_interface" "network-interface-frontend" {
  name                = "network-interface-frontend"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public-ip-frontend.id
  }
}

resource "azurerm_subnet_network_security_group_association" "association-ni-sg-backend" {
  subnet_id                 = azurerm_subnet.private_subnet.id
  network_security_group_id = azurerm_network_security_group.security-group-backend.id
}

resource "azurerm_network_interface_security_group_association" "association-ni-sg-frontend" {
  network_interface_id      = azurerm_network_interface.network-interface-frontend.id
  network_security_group_id = azurerm_network_security_group.security-group-frontend.id
}
