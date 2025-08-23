# Linux VM with Managed Identity
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.rg_name}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic.id]

  identity {
    type = "SystemAssigned"
  }

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

app = Flask(__name__)
credential = DefaultAzureCredential()
compute_client = ComputeManagementClient(credential, "${var.subscription_id}")

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

    nohup python3 app.py &
  EOF
  )
}

# Assign Reader role to the Managed Identity
resource "azurerm_role_assignment" "vm_reader" {
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id
  role_definition_name = "Reader"
  scope                = azurerm_resource_group.rg.id
}
