resource "azurerm_resource_group" "jenkins-rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "jenkins-vnet" {
  name                = var.virtual_network_name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.jenkins-rg.location
  resource_group_name = azurerm_resource_group.jenkins-rg.name
}

resource "azurerm_subnet" "jenkins-subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.jenkins-rg.name
  virtual_network_name = azurerm_virtual_network.jenkins-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "jenkins-ip" {
  name                = var.public_ip_name
  resource_group_name = azurerm_resource_group.jenkins-rg.name
  location            = azurerm_resource_group.jenkins-rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "jenkins-nsg" {
  name                = var.network_security_group_name
  location            = azurerm_resource_group.jenkins-rg.location
  resource_group_name = azurerm_resource_group.jenkins-rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "jenkins-nic" {
  name                = var.network_interface_name
  location            = azurerm_resource_group.jenkins-rg.location
  resource_group_name = azurerm_resource_group.jenkins-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jenkins-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.jenkins-ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "jenkins-nicsg" {
  network_interface_id = azurerm_network_interface.jenkins-nic.id
  network_security_group_id = azurerm_network_security_group.jenkins-nsg.id
}

resource "random_id" "random_id" {
  keepers = {
    resource_group = azurerm_resource_group.jenkins-rg.name
  }

  byte_length = 8
}

resource "azurerm_storage_account" "jenkins-storage-account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.jenkins-rg.location
  resource_group_name      = azurerm_resource_group.jenkins-rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_linux_virtual_machine" "jenkins-vm" {
  name                = var.virtual_machine_name
  resource_group_name = azurerm_resource_group.jenkins-rg.name
  location            = azurerm_resource_group.jenkins-rg.location
  size                = "Standard_D2s_v3"
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.jenkins-nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("../Credential/jenkinskey.pub")
  }

  os_disk {
    name                 = var.os_disk_name
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb = 100
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.jenkins-storage-account.primary_blob_endpoint
  }

}