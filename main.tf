

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.rg_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "${var.rg_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# NSG
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.rg_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Public IP
resource "azurerm_public_ip" "ip" {
  name                = "${var.rg_name}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Network Interface
resource "azurerm_network_interface" "nic" {
  name                = "${var.rg_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id           = azurerm_public_ip.ip.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.rg_name}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt update
    apt install -y python3-pip git
    pip3 install flask azure-identity azure-mgmt-compute
    mkdir -p /home/${var.admin_username}/flaskapp
    cd /home/${var.admin_username}/flaskapp

    # Flask app
    cat <<'APP' > app.py
from flask import Flask, render_template_string
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient
import os

app = Flask(__name__)

subscription_id = os.environ.get("AZURE_SUBSCRIPTION_ID")
credential = DefaultAzureCredential()
compute_client = ComputeManagementClient(credential, subscription_id)

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head><title>Azure VM Dashboard</title></head>
<body>
<h1>Azure VM Dashboard</h1>
<table border="1">
<tr><th>Name</th><th>Resource Group</th><th>Location</th></tr>
{% for vm in vms %}
<tr><td>{{ vm.name }}</td><td>{{ vm.resource_group }}</td><td>{{ vm.location }}</td></tr>
{% endfor %}
</table>
</body>
</html>
"""

@app.route("/")
def index():
    vms = []
    for vm in compute_client.virtual_machines.list_all():
        vms.append({
            "name": vm.name,
            "location": vm.location,
            "resource_group": vm.id.split("/")[4]
        })
    return render_template_string(HTML_TEMPLATE, vms=vms)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
APP

    export AZURE_SUBSCRIPTION_ID="${var.subscription_id}"
    nohup python3 app.py &
  EOF
  )
}
