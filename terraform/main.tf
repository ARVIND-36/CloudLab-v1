# =============================================================================
# CloudLab: On-Demand DevOps Lab Platform
# Terraform Main Configuration — Azure Infrastructure
# =============================================================================
# This file defines all Azure resources required for a single lab VM:
#   - Resource Group
#   - Virtual Network & Subnet
#   - Network Security Group (SSH access on port 22)
#   - Public IP Address
#   - Network Interface
#   - Linux Virtual Machine (Ubuntu 22.04 LTS)
# =============================================================================

# ---------------------------------------------------------------------------
# Azure Provider Configuration
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

provider "azurerm" {
  features {}
}

# ---------------------------------------------------------------------------
# Resource Group — Logical container for all lab resources
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "cloudlab_rg" {
  name     = "rg-cloudlab-${lower(replace(var.azure_region, " ", "-"))}"
  location = var.azure_region

  tags = {
    Project     = "CloudLab"
    Environment = "DevOps-Lab"
    ManagedBy   = "Terraform"
  }
}

# ---------------------------------------------------------------------------
# Virtual Network — Isolated network for the lab VM
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "cloudlab_vnet" {
  name                = "vnet-cloudlab"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.cloudlab_rg.location
  resource_group_name = azurerm_resource_group.cloudlab_rg.name

  tags = {
    Project = "CloudLab"
  }
}

# ---------------------------------------------------------------------------
# Subnet — A dedicated subnet within the VNet for lab VMs
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "cloudlab_subnet" {
  name                 = "subnet-cloudlab"
  resource_group_name  = azurerm_resource_group.cloudlab_rg.name
  virtual_network_name = azurerm_virtual_network.cloudlab_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ---------------------------------------------------------------------------
# Network Security Group — Firewall rules for the lab VM
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "cloudlab_nsg" {
  name                = "nsg-cloudlab"
  location            = azurerm_resource_group.cloudlab_rg.location
  resource_group_name = azurerm_resource_group.cloudlab_rg.name

  # Allow inbound SSH traffic on port 22
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Project = "CloudLab"
  }
}

# ---------------------------------------------------------------------------
# Public IP Address — External-facing IP for SSH access
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "cloudlab_pip" {
  name                = "pip-cloudlab-vm"
  location            = azurerm_resource_group.cloudlab_rg.location
  resource_group_name = azurerm_resource_group.cloudlab_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Project = "CloudLab"
  }
}

# ---------------------------------------------------------------------------
# Network Interface — Connects the VM to the VNet and Public IP
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "cloudlab_nic" {
  name                = "nic-cloudlab-vm"
  location            = azurerm_resource_group.cloudlab_rg.location
  resource_group_name = azurerm_resource_group.cloudlab_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.cloudlab_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.cloudlab_pip.id
  }

  tags = {
    Project = "CloudLab"
  }
}

# ---------------------------------------------------------------------------
# NSG ↔ NIC Association — Attach security rules to the network interface
# ---------------------------------------------------------------------------
resource "azurerm_network_interface_security_group_association" "cloudlab_nic_nsg" {
  network_interface_id      = azurerm_network_interface.cloudlab_nic.id
  network_security_group_id = azurerm_network_security_group.cloudlab_nsg.id
}

# ---------------------------------------------------------------------------
# Linux Virtual Machine — The actual lab environment
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "cloudlab_vm" {
  name                = "vm-cloudlab-lab"
  location            = azurerm_resource_group.cloudlab_rg.location
  resource_group_name = azurerm_resource_group.cloudlab_rg.name
  size                = var.vm_size

  # Authentication — SSH key-based (no password)
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  # Attach the network interface
  network_interface_ids = [
    azurerm_network_interface.cloudlab_nic.id
  ]

  # OS Disk configuration
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "osdisk-cloudlab-vm"
  }

  # Ubuntu 22.04 LTS image from Canonical
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    Project     = "CloudLab"
    Environment = "DevOps-Lab"
    ManagedBy   = "Terraform"
  }
}
