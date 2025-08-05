import os
from flask import Flask, render_template, jsonify
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient

app = Flask(__name__)

# Load Azure Subscription ID from environment variable
subscription_id = os.getenv("SUBSCRIPTION_ID", "84a4c20d-c4cc-44d6-8a5b-23f7253c12c4")

# Authenticate using Managed Identity / Service Principal
credential = DefaultAzureCredential()
compute_client = ComputeManagementClient(credential, subscription_id)

def get_vm_inventory():
    vm_list = []
    for vm in compute_client.virtual_machines.list_all():
        # Extract resource group from the VM ID
        resource_group = vm.id.split("/")[4]

        # Get VM instance view to check power status
        instance_view = compute_client.virtual_machines.instance_view(
            resource_group,
            vm.name
        )
        status = "Unknown"
        if instance_view.statuses:
            status = instance_view.statuses[-1].display_status

        vm_list.append({
            "name": vm.name,
            "resource_group": resource_group,
            "location": vm.location,
            "size": vm.hardware_profile.vm_size,
            "os_type": vm.storage_profile.os_disk.os_type.value,
            "status": status
        })
    return vm_list

@app.route("/")
def home():
    return render_template("index.html")

@app.route("/api/vms")
def api_vms():
    return jsonify(get_vm_inventory())

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
