data "azurerm_user_assigned_identity" "identity-acr" {
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  name                = "identity-acr"
}

data "azurerm_storage_account" "public-storage-account" {
  name                = "${var.prefix}psa"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
}

data "azurerm_storage_container" "public-storage-container" {
  name                 = "${var.prefix}psc"
  storage_account_name = data.azurerm_storage_account.public-storage-account.name
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

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  connection {
    host        = self.public_ip_address
    user        = "adminuser"
    type        = "ssh"
    private_key = file("${path.module}/../id_rsa")
    timeout     = "1m"
    agent       = true
  }

  provisioner "file" {
    source      = "${path.module}/provision-docker.sh"
    destination = "/home/adminuser/provision-docker.sh"
  }

  provisioner "file" {
    source      = "${path.module}/provision-quotes.sh"
    destination = "/home/adminuser/provision-quotes.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/adminuser/provision-docker.sh",
      "/home/adminuser/provision-docker.sh"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/adminuser/provision-quotes.sh",
      <<EOF
      /home/adminuser/provision-quotes.sh ${var.prefix}quotes${var.acr_url_default}/${var.prefix}quotes:latest ${data.azurerm_user_assigned_identity.identity-acr.id} ${var.prefix}quotes   
      EOF
    ]
  }

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

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  connection {
    host        = self.public_ip_address
    user        = "adminuser"
    type        = "ssh"
    private_key = file("${path.module}/../id_rsa")
    timeout     = "1m"
    agent       = true
  }

  provisioner "file" {
    source      = "${path.module}/provision-docker.sh"
    destination = "/home/adminuser/provision-docker.sh"
  }

  provisioner "file" {
    source      = "${path.module}/provision-newsfeed.sh"
    destination = "/home/adminuser/provision-newsfeed.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/adminuser/provision-docker.sh",
      "/home/adminuser/provision-docker.sh"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/adminuser/provision-newsfeed.sh",
      <<EOF
      /home/adminuser/provision-newsfeed.sh ${var.prefix}newsfeed${var.acr_url_default}/${var.prefix}newsfeed:latest ${data.azurerm_user_assigned_identity.identity-acr.id} ${var.prefix}newsfeed    
      EOF
    ]
  }

}

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

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  connection {
    host        = self.public_ip_address
    user        = "adminuser"
    type        = "ssh"
    private_key = file("${path.module}/../id_rsa")
    timeout     = "1m"
    agent       = true
  }

  provisioner "file" {
    source      = "${path.module}/provision-docker.sh"
    destination = "/home/adminuser/provision-docker.sh"
  }

  provisioner "file" {
    source      = "${path.module}/provision-frontend.sh"
    destination = "/home/adminuser/provision-frontend.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/adminuser/provision-docker.sh",
      "/home/adminuser/provision-docker.sh"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/adminuser/provision-frontend.sh",
      <<EOF
      /home/adminuser/provision-frontend.sh ${var.prefix}frontend${var.acr_url_default}/${var.prefix}frontend:latest ${data.azurerm_user_assigned_identity.identity-acr.id} ${var.prefix}frontend http://${azurerm_linux_virtual_machine.virtual-machine-quotes.private_ip_address}:8082 http://${azurerm_linux_virtual_machine.virtual-machine-newsfeed.private_ip_address}:8081 ${local.url_static_blob}
      EOF
    ]
  }

}

output "frontend_url" {
  value = "http://${azurerm_linux_virtual_machine.virtual-machine-frontend.public_ip_address}:8080"
}
