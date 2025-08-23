# -----------------------
# Resource Group
# -----------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# -----------------------
# VNet & Subnet
# -----------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "vm-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# -----------------------
# Public IP
# -----------------------
resource "azurerm_public_ip" "public_ip" {
  name                = "${var.vm_name}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# -----------------------
# NSG
# -----------------------
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.vm_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# -----------------------
# NIC
# -----------------------
resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# -----------------------
# Linux VM
# -----------------------
resource "azurerm_linux_virtual_machine" "web" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

# -----------------------
# Custom Script Extension (Flask dashboard)
# -----------------------
resource "azurerm_virtual_machine_extension" "flask_dashboard" {
  name                 = "flask-dashboard"
  virtual_machine_id   = azurerm_linux_virtual_machine.web.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    commandToExecute = <<EOT
sudo apt-get update -y && \
sudo apt-get install -y python3 python3-venv python3-pip && \
mkdir -p /opt/vm-dashboard && cd /opt/vm-dashboard && \
python3 -m venv .venv && . .venv/bin/activate && \
pip install flask gunicorn && \
cat > /opt/vm-dashboard/app.py << 'PYCODE'
from flask import Flask
import subprocess
app = Flask(__name__)
@app.route('/')
def home():
    hostname = subprocess.getoutput('hostname')
    return f'<h1>Azure VM Dashboard</h1><p>VM Name: {hostname}</p>'
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
PYCODE
&& cat > /etc/systemd/system/vm-dashboard.service << 'UNIT'
[Unit]
Description=Azure VM Dashboard (Flask via Gunicorn)
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
WorkingDirectory=/opt/vm-dashboard
ExecStart=/opt/vm-dashboard/.venv/bin/gunicorn --bind 0.0.0.0:80 app:app
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
UNIT
&& systemctl daemon-reload && systemctl enable --now vm-dashboard.service
EOT
  })
}
