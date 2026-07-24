#refernce public ip for lb
data "azurerm_public_ip" "public-ip-lb" {
  name                = "public-ip-lb"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
}

data "azurerm_user_assigned_identity" "identity-acr" {
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  name                = "identity-acr"
}

data "azurerm_storage_account" "public-storage-account" {
  name                = "${var.prefix}psa"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
}

# Attaching azure storage account to user assigned identity so it can be used to authenticate requests coming to blob conatiner 
resource "azurerm_role_assignment" "storage" {
  scope                = azurerm_storage_account.public-storage-account.id
  role_definition_name = "Storage Blob Data Reader"

  principal_id = data.azurerm_user_assigned_identity.identity-acr.principal_id
}

data "azurerm_storage_container" "public-storage-container" {
  name                 = "${var.prefix}psc"
  storage_account_name = data.azurerm_storage_account.public-storage-account.name
}

# upload docker.sh file to blob 
resource "azurerm_storage_blob" "provision_docker" {
  name                   = "provision-docker"
  storage_account_name   = azurerm_storage_account.public-storage-account.name
  storage_container_name = azurerm_storage_container.public-storage-container.name
  type                   = "Block"

  source = "${path.module}/provision-docker.sh"
}

# upload quotes.sh file to blob
resource "azurerm_storage_blob" "provision_quotes" {
  name                   = "provision-quotes"
  storage_account_name   = azurerm_storage_account.public-storage-account.name
  storage_container_name = azurerm_storage_container.public-storage-container.name
  type                   = "Block"

  source = "${path.module}/provision-quotes.sh"
}

resource "azurerm_storage_blob" "provision_newsfeed" {
  name                   = "provision-newsfeed"
  storage_account_name   = azurerm_storage_account.public-storage-account.name
  storage_container_name = azurerm_storage_container.public-storage-container.name
  type                   = "Block"

  source = "${path.module}/provision-newsfeed.sh"
}

resource "azurerm_storage_blob" "provision_frontend" {
  name                   = "provision-frontend"
  storage_account_name   = azurerm_storage_account.public-storage-account.name
  storage_container_name = azurerm_storage_container.public-storage-container.name
  type                   = "Block"

  source = "${path.module}/provision-frontend.sh"
}

data "azurerm_network_interface" "network-interface-quotes" {
  name                = "network-interface-quotes"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
}

data "azurerm_network_interface" "network-interface-newsfeed" {
  name                = "network-interface-newsfeed"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
}

data "azurerm_network_interface" "network-interface-frontend" {
  name                = "network-interface-frontend"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
}

locals {
  url_static_blob = "https://${data.azurerm_storage_account.public-storage-account.name}.blob.core.windows.net/${data.azurerm_storage_container.public-storage-container.name}"
}

# key vault setup 
resource "azurerm_key_vault" "app" {
  name                = "${var.prefix}-app-kv"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"

  enable_rbac_authorization = true

  soft_delete_retention_days = 7
  purge_protection_enabled   = true
}

resource "azurerm_linux_virtual_machine" "virtual-machine-quotes" {
  name                = "quotes"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    data.azurerm_network_interface.network-interface-quotes.id
  ]

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.identity-acr.id]
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("${path.module}/../id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Use latest avaiable ubuntu as support for 18.04 is depriciated
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

}

# Use VM extensions to run bash scripts quotes
resource "azurerm_virtual_machine_extension" "quotes" {
  name                 = "quotes-provisioning"
  virtual_machine_id   = azurerm_linux_virtual_machine.virtual-machine-quotes.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  protected_settings = jsonencode({
    fileUris = [
      azurerm_storage_blob.provision_docker.url,
      azurerm_storage_blob.provision_quotes.url
    ]

    commandToExecute = join(" ", [
      "chmod +x provision-docker.sh provision-quotes.sh &&",
      "./provision-docker.sh &&",
      "./provision-quotes.sh",
      "'${var.prefix}quotes${var.acr_url_default}/${var.prefix}quotes:latest'",
      "'${data.azurerm_user_assigned_identity.identity-acr.id}'",
      "'${var.prefix}quotes'"
    ])

    managedIdentity = {
      clientId = data.azurerm_user_assigned_identity.identity-acr.client_id
    }
  })

  depends_on = [
    azurerm_role_assignment.storage
  ]
}

resource "azurerm_linux_virtual_machine" "virtual-machine-newsfeed" {
  name                = "newsfeed"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    data.azurerm_network_interface.network-interface-newsfeed.id
  ]

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.identity-acr.id]
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("${path.module}/../id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Use latest avaiable ubuntu as support for 18.04 is depriciated
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

}

# Use VM extensions to run bash scripts newsfeed
resource "azurerm_virtual_machine_extension" "newsfeed" {
  name                 = "newsfeed-provisioning"
  virtual_machine_id   = azurerm_linux_virtual_machine.virtual-machine-newsfeed.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  protected_settings = jsonencode({
    fileUris = [
      azurerm_storage_blob.provision_docker.url,
      azurerm_storage_blob.provision_newsfeed.url
    ]

    commandToExecute = join(" ", [
      "chmod +x provision-docker.sh provision-newsfeed.sh &&",
      "./provision-docker.sh &&",
      "./provision-newsfeed.sh",
      "'${var.prefix}newsfeed${var.acr_url_default}/${var.prefix}newsfeed:latest'",
      "'${data.azurerm_user_assigned_identity.identity-acr.id}'",
      "'${var.prefix}newsfeed'"
    ])

    managedIdentity = {
      clientId = data.azurerm_user_assigned_identity.identity-acr.client_id
    }
  })

  depends_on = [
    azurerm_role_assignment.storage
  ]
}


# Use VM extensions to run bash scripts quotes
resource "azurerm_linux_virtual_machine" "virtual-machine-frontend" {
  name                = "frontend"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    data.azurerm_network_interface.network-interface-frontend.id
  ]

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.identity-acr.id]
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("${path.module}/../id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Use latest avaiable ubuntu as support for 18.04 is depriciated
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

}

#Give VM identity read permissions to key vaulr secret
resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets User"

  principal_id = data.azurerm_user_assigned_identity.identity-acr.principal_id
}

resource "azurerm_virtual_machine_extension" "frontend" {
  name                 = "frontend-provisioning"
  virtual_machine_id   = azurerm_linux_virtual_machine.virtual-machine-frontend.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  protected_settings = jsonencode({
    fileUris = [
      azurerm_storage_blob.provision_docker.url,
      azurerm_storage_blob.provision_frontend.url
    ]

    commandToExecute = join(" ", [
      "chmod +x provision-docker.sh provision-frontend.sh &&",
      "./provision-docker.sh &&",
      "./provision-frontend.sh",
      "'${var.prefix}frontend${var.acr_url_default}/${var.prefix}frontend:latest'",
      "'${data.azurerm_user_assigned_identity.identity-acr.id}'",
      "'${var.prefix}frontend'",
      "'http://${azurerm_linux_virtual_machine.virtual-machine-quotes.private_ip_address}:8082'",
      "'http://${azurerm_linux_virtual_machine.virtual-machine-newsfeed.private_ip_address}:8081'",
      "'${local.url_static_blob}'",
      "'${azurerm_key_vault.app.name}'"
    ])

    managedIdentity = {
      clientId = data.azurerm_user_assigned_identity.identity-acr.client_id
    }
  })

  depends_on = [
    azurerm_role_assignment.storage,
    azurerm_virtual_machine_extension.quotes,
    azurerm_virtual_machine_extension.newsfeed
  ]
}

output "frontend_url" {
  value = "http://${azurerm_public_ip.public-ip-frontend.ip_address}:8080"
}
