resource "azurerm_resource_group" "Jenkins-rg" {
  name     = var.rg
  location = var.location
}

resource "azurerm_virtual_network" "Jenkins-vnet" {
  name                = var.vnet
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.Jenkins-rg.location
  resource_group_name = azurerm_resource_group.Jenkins-rg.name
}

resource "azurerm_subnet" "Jenkins-subnet" {
  name                 = var.subnet
  resource_group_name  = azurerm_resource_group.Jenkins-rg.name
  virtual_network_name = azurerm_virtual_network.Jenkins-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "Jenkins-ip" {
  name                = var.ip
  resource_group_name = azurerm_resource_group.Jenkins-rg.name
  location            = azurerm_resource_group.Jenkins-rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "Jenkins-nsg" {
  name                = var.nsg
  location            = azurerm_resource_group.Jenkins-rg.location
  resource_group_name = azurerm_resource_group.Jenkins-rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "Jenkins-nic" {
  name                = var.nic
  location            = azurerm_resource_group.Jenkins-rg.location
  resource_group_name = azurerm_resource_group.Jenkins-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.Jenkins-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.Jenkins-ip.id
  }
}

resource "azurerm_linux_virtual_machine" "Jenkins-vm" {
  name                = var.vm
  resource_group_name = azurerm_resource_group.Jenkins-rg.name
  location            = azurerm_resource_group.Jenkins-rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "Slave-VM"
  network_interface_ids = [
    azurerm_network_interface.Jenkins-nic.id
  ]

  admin_ssh_key {
    username   = "Slave-VM"
    public_key = file("../KeyVM/slavevm.pub")
  }

  os_disk {
    name                 = "Jenkins-disk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb = 60
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}