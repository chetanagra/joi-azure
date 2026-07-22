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

