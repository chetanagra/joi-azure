
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

  # Storage firewall can recognize/allow traffic from this subnet
  service_endpoints = [
    "Microsoft.Storage"
  ]
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

# public ip for lb
resource "azurerm_public_ip" "public-ip-lb" {
  name                = "public-ip-lb"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = azurerm_virtual_network.virtual-network.location
  allocation_method = "Static"
  sku               = "Standard"
}

# Create Load balancer
resource "azurerm_lb" "frontend-lb" {
  name                = "frontend-lb"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "lb-public-ip"
    public_ip_address_id = azurerm_public_ip.public-ip-lb.id
  }
}

#Create lb backend pool
resource "azurerm_lb_backend_address_pool" "lb-backend-pool" {
  name            = "lb-backend-pool"
  loadbalancer_id = azurerm_lb.frontend-lb.id
}

#Create backend pool association to frontend VM NIC
resource "azurerm_network_interface_backend_address_pool_association" "frontend" {
  network_interface_id    = azurerm_network_interface.network-interface-frontend.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb-backend-pool.id
}

# Heath check for frontend
resource "azurerm_lb_probe" "frontend" {
  name            = "frontend-health-probe"
  loadbalancer_id = azurerm_lb.frontend-lb.id

  protocol = "Tcp"
  port     = 8080
}

# Create a rule to map VM PORT with public port
resource "azurerm_lb_rule" "frontend-lb" {
  name            = "frontend-lb"
  loadbalancer_id = azurerm_lb.frontend-lb.id

  protocol      = "Tcp"
  frontend_port = 8080
  backend_port  = 8080

  frontend_ip_configuration_name = "frontend-public-ip"
  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.frontend.id
  ]

  probe_id = azurerm_lb_probe.frontend.id
}

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

resource "azurerm_network_security_group" "security-group-frontend-lb" {
  name                = "security-group-frontend-lb"
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

resource "azurerm_network_security_rule" "rule-inbound-frontend" {
  name                        = "rule-inbound-frontend"
  priority                    = 1008
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.azure-resource.name
  network_security_group_name = azurerm_network_security_group.security-group-frontend.name
}

# NIC for newsfeed
resource "azurerm_network_interface" "network-interface-newsfeed" {
  name                = "network-interface-newsfeed"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private_subnet.id   # ← changed
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id removed — backend has no public IP
  }
}

# NIC for quotes
resource "azurerm_network_interface" "network-interface-quotes" {
  name                = "network-interface-quotes"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private_subnet.id   # ← changed
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id removed — backend has no public IP
  }
}

# NIC for frontend 
resource "azurerm_network_interface" "network-interface-frontend" {
  name                = "network-interface-frontend"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_subnet_network_security_group_association" "association-ni-sg-quotes" {
  subnet_id                 = azurerm_subnet.private_subnet.id
  network_security_group_id = azurerm_network_security_group.security-group-backend.id
}

resource "azurerm_subnet_network_security_group_association" "association-ni-sg-newsfeed" {
  subnet_id                 = azurerm_subnet.private_subnet.id
  network_security_group_id = azurerm_network_security_group.security-group-backend.id
}

resource "azurerm_network_interface_security_group_association" "association-ni-sg-frontend" {
  network_interface_id      = azurerm_network_interface.network-interface-frontend.id
  network_security_group_id = azurerm_network_security_group.security-group-frontend.id
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb-backend-pool.id
}
