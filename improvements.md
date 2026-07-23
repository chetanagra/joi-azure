# infra/backend-support/provider.tf - 
  not required as no resource is getting created 

# infra/base/acr.tf - 
  local file creation is not needed as it isn't being used any where 

  can add resource to prevent accidental deletion of registries :-
    
    resource "azurerm_management_lock" "quotes_lock" {
      name       = "delete-lock"
      scope      = azurerm_container_registry.quotes.id
      lock_level = "CanNotDelete"
      notes      = "Prevent accidental deletion of ACR"
    }
    
    resource "azurerm_management_lock" "newsfeed_lock" {
      name       = "delete-lock"
      scope      = azurerm_container_registry.newsfeed.id
      lock_level = "CanNotDelete"
    }
    
    resource "azurerm_management_lock" "frontend_lock" {
      name       = "delete-lock"
      scope      = azurerm_container_registry.frontend.id
      lock_level = "CanNotDelete"
    }

  can enable microsoft defender for conatiner registries which do vulenarablitiy scan for all acrs 

    resource "azurerm_security_center_subscription_pricing" "defender_container_registry" {
    tier          = "Standard"
    resource_type = "ContainerRegistry"
    }

# infra/base/avn.tf

  instead of allowing ssh to all we should putlist of trusted cidrs:

    variable "allowed_ssh_cidrs" {
      type    = list(string)
      default = ["203.0.113.10/32"]
    }

    resource "azurerm_network_security_rule" "rule-inbound-ssh-quotes" {
      source_address_prefix       = var.allowed_ssh_cidrs
    }

  Change source_address_prefix = "*" and destination_address_prefix = "*" to source_address_prefix = "VirtualNetwork" and destination_address_prefix = "VirtualNetwork" in inbound rukes for news feed and quotes as they  don't require to be accessible over internet. this change will allow them accessible only from same subnet 

  No need of public IPS for qoutes and newsfeed as they are not being accessed publically Instead newsfeed and quotes should be in privates subnet

    resource "azurerm_subnet" "private_subnet" {
      name                 = "private_subnet"
      resource_group_name  = data.azurerm_resource_group.azure-resource.name
      virtual_network_name = azurerm_virtual_network.virtual-network.name
      address_prefixes     = ["10.5.3.0/24"]
    }

    #Create public IP for NAT gateway
    resource "azurerm_public_ip" "nat-public-ip" {
      name                = "nat-public-ip"
      location            = var.location
      resource_group_name = data.azurerm_resource_group.azure-resource.name
      allocation_method   = "Static"
      sku                 = "Standard"
    }

    #Create NAT gateway
    resource "azurerm_nat_gateway" "nat-gateway" {
      name                = "nat-gateway"
      location            = var.location
      resource_group_name = data.azurerm_resource_group.azure-resource.name
      sku_name            = "Standard"
    }

    #Attach public ip to NAT Gateway
    resource "azurerm_nat_gateway_public_ip_association" "nat-ip-assoc" {
      nat_gateway_id       = azurerm_nat_gateway.nat-gateway.id
      public_ip_address_id = azurerm_public_ip.nat-public-ip.id
    }
    
    # Attach the NAT Gateway to the private subnet
    resource "azurerm_subnet_nat_gateway_association" "private-subnet-nat" {
      subnet_id      = azurerm_subnet.private_subnet.id
      nat_gateway_id = azurerm_nat_gateway.nat-gateway.id
    }

    # Associate NICs for newfeed and quotes to private subnet
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

    #Attach NSGs to private subnet for newsfeed and quotes service
    resource "azurerm_subnet_network_security_group_association" "private-subnet-nsg-quotes" {
      subnet_id                 = azurerm_subnet.private_subnet.id
      network_security_group_id = azurerm_network_security_group.security-group-quotes.id
    }

# infra/base/blob.tf

  Enable https only traffic 

    resource "azurerm_storage_account" "public-storage-account" {
      enable_https_traffic_only = true
    }

  Enforce min TLS version 
    
    resource "azurerm_storage_account" "public-storage-account" {
      minimum_tls_version = "TLS1_2"
    }

  Restrict public access for blob 

    resource "azurerm_storage_container" "public-storage-container" {
      container_access_type = "private"  # Instead of "blob"
    }

  Add sensitive = true to avoid exposing URL in terraform apply or use managed identity to access blob container instead of url
  
    output "url_blob" {
      sensitive = true
      value     = "https://storageaccount.blob.core.windows.net/container/static/"
    }

    
# infra/news/main.tf

  use key vault to pass ssh keys

    data "azurerm_client_config" "current" {}

    # ── Key Vault to store SSH keys ─────────────────────────────────────
    resource "azurerm_key_vault" "ssh_kv" {
      name                       = "${var.prefix}sshkv"
      location                   = var.location
      resource_group_name        = data.azurerm_resource_group.azure-resource.name
      tenant_id                  = data.azurerm_client_config.current.tenant_id
      sku_name                   = "standard"
      purge_protection_enabled   = true
      soft_delete_retention_days = 7
      enable_rbac_authorization  = false
    }
    
    # ── Store the PUBLIC key as a secret ───────────────────────────────
    resource "azurerm_key_vault_secret" "ssh_public_key" {
      name         = "ssh-public-key"
      value        = file("${path.module}/../id_rsa.pub")
      key_vault_id = azurerm_key_vault.ssh_kv.id
    }
    
    # ── Store the PRIVATE key as a secret ──────────────────────────────
    resource "azurerm_key_vault_secret" "ssh_private_key" {
      name         = "ssh-private-key"
      value        = file("${path.module}/../id_rsa")
      key_vault_id = azurerm_key_vault.ssh_kv.id
    }
    
    # ── Access policy so Terraform can read secrets ────────────────────
    resource "azurerm_key_vault_access_policy" "terraform_access" {
      key_vault_id = azurerm_key_vault.ssh_kv.id
      tenant_id    = data.azurerm_client_config.current.tenant_id
      object_id    = data.azurerm_client_config.current.object_id
    
      secret_permissions = ["Get", "List"]
    }

    # Read public key 
    admin_ssh_key {
      username   = "adminuser"
      public_key = azurerm_key_vault_secret.ssh_public_key.value
    }

    # Read Private key from vault
    connection {
      host        = self.public_ip_address
      user        = "adminuser"
      type        = "ssh"
      private_key = azurerm_key_vault_secret.ssh_private_key.value
      timeout     = "1m"
      agent       = false    # ✅ Changed to false — using private_key directly
    }


  enable encryption on disk add this line to VM configs  encryption_at_host_enabled = true 


  use update image instead of 18.04 use 22_04-lts as standard-support ended in April 2023


  
  
  


  

  


  
  

    

  
