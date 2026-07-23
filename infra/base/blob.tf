
resource "azurerm_storage_account" "public-storage-account" {
  name                     = "${var.prefix}psa"
  resource_group_name      = data.azurerm_resource_group.azure-resource.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  enable_https_traffic_only = true # Enable https only traffic
  minimum_tls_version = "TLS1_2" # Enforces min TLS version
}

resource "azurerm_storage_container" "public-storage-container" {
  name                  = "${var.prefix}psc"
  storage_account_name  = azurerm_storage_account.public-storage-account.name
  container_access_type = "blob"  # Instead of "blob" use private to restrict pulic access 
}

resource "azurerm_storage_blob" "blob-static" {
  name                   = "static"
  storage_account_name   = azurerm_storage_account.public-storage-account.name
  storage_container_name = azurerm_storage_container.public-storage-container.name
  type                   = "Block"
}

#Instead use Private access 
/*
output "url_blob" {
  value = "https://${azurerm_storage_account.public-storage-account.name}.blob.core.windows.net/${azurerm_storage_container.public-storage-container.name}/static/"
}
*/


