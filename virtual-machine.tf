# Create resource group
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

# Create virtual network
resource "azurerm_virtual_network" "this" {
  name                = var.virtual_network_name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

# Create subnet
resource "azurerm_subnet" "this" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "this" {
  count               = var.linux_vms.instance_count
  name                = format("%s-nic%s", var.vm_names[count.index], (var.linux_vms.start_index + count.index))
  location            = azurerm_virtual_network.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  depends_on            = [azurerm_resource_group.this, azurerm_network_interface.this]
  count                 = var.linux_vms.instance_count
  name                  = var.vm_names[count.index]
  location              = azurerm_virtual_network.this.location
  resource_group_name   = azurerm_resource_group.this.name
  tags                  = var.vm_tags
  size                  = var.linux_vms.size
  network_interface_ids = [azurerm_network_interface.this[count.index].id]

  dynamic "source_image_reference" {
    for_each = [var.linux_vms.image_reference]
    content {
      publisher = source_image_reference.value.publisher
      offer     = source_image_reference.value.offer
      sku       = source_image_reference.value.sku
      version   = source_image_reference.value.version
    }
  }

 admin_ssh_key {
    username   = var.username
    public_key = jsondecode(azapi_resource_action.ssh_public_key_gen.output).publicKey
  }


  os_disk {
    caching              = var.linux_vms.os_disk.caching
    storage_account_type = var.linux_vms.os_disk.storage_account_type
    name                 = format("%s-osdisk%s", var.vm_names[count.index], (var.linux_vms.start_index + count.index))
  }

  computer_name  = "hostname"
  admin_username = var.username
}

# Path: variables.tf
