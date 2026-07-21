
resource "azurerm_user_assigned_identity" "identity-acr" {
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  name                = "identity-acr"
}
resource "azurerm_container_registry" "quotes" {
  name                = "${var.prefix}quotes"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
}

resource "azurerm_container_registry" "newsfeed" {
  name                = "${var.prefix}newsfeed"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
}

resource "azurerm_container_registry" "frontend" {
  name                = "${var.prefix}frontend"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
}
resource "random_uuid" "acrpull_id_frontend" {
  keepers = {
    acr_id = "${azurerm_container_registry.frontend.id}"
    sp_id  = "${azurerm_user_assigned_identity.identity-acr.principal_id}"
    role   = "AcrPull"
  }
}

resource "random_uuid" "acrpull_id_quotes" {
  keepers = {
    acr_id = "${azurerm_container_registry.quotes.id}"
    sp_id  = "${azurerm_user_assigned_identity.identity-acr.principal_id}"
    role   = "AcrPull"
  }
}

resource "random_uuid" "acrpull_id_newsfeed" {
  keepers = {
    acr_id = "${azurerm_container_registry.newsfeed.id}"
    sp_id  = "${azurerm_user_assigned_identity.identity-acr.principal_id}"
    role   = "AcrPull"
  }
}

data "azurerm_role_definition" "acrpull" {
  name = "AcrPull"
}

resource "azurerm_role_assignment" "acr_acrpull_quotes" {
  name               = random_uuid.acrpull_id_quotes.result
  scope              = azurerm_container_registry.quotes.id
  role_definition_id = data.azurerm_role_definition.acrpull.id
  principal_id       = azurerm_user_assigned_identity.identity-acr.principal_id
}

resource "azurerm_role_assignment" "acr_acrpull_newsfeed" {
  name               = random_uuid.acrpull_id_newsfeed.result
  scope              = azurerm_container_registry.newsfeed.id
  role_definition_id = data.azurerm_role_definition.acrpull.id
  principal_id       = azurerm_user_assigned_identity.identity-acr.principal_id
}

resource "azurerm_role_assignment" "acr_acrpull_frontend" {
  name               = random_uuid.acrpull_id_frontend.result
  scope              = azurerm_container_registry.frontend.id
  role_definition_id = data.azurerm_role_definition.acrpull.id
  principal_id       = azurerm_user_assigned_identity.identity-acr.principal_id
}

locals {
  acr_url = ".azurecr.io"
}

resource "local_file" "acr" {
  filename = "${path.module}/../acr-url.txt"
  content  = local.acr_url
}