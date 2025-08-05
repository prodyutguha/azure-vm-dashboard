import os
import threading
from flask import Flask, render_template, jsonify

app = Flask(__name__)

# Cache to store VM data
vm_cache = []
is_loading = False

def fetch_vm_inventory():
    """Fetch VM inventory in the background to avoid timeouts."""
    global vm_cache, is_loading
    is_loading = True
    vm_cache = []

    try:
        subscription_id = os.getenv("SUBSCRIPTION_ID")
        if not subscription_id:
            vm_cache = [{"error": "SUBSCRIPTION_ID is missing in App Settings"}]
            is_loading = False
            return

        from azure.identity import DefaultAzureCredential
        from azure.mgmt.compute import ComputeManagementClient

        credential = DefaultAzureCredential()
        compute_client = ComputeManagementClient(credential, subscription_id)

        temp_list = []
        for vm in compute_client.virtual_machines.list_all():
            resource_group = vm.id.split("/")[4]

            # Get instance view for power status (safe)
            try:
                instance_view = compute_client.virtual_machines.instance_view(
                    resource_group, vm.name
                )
                status = instance_view.statuses[-1].display_status if instance_view.statuses else "Unknown"
            except Exception:
                status = "Unknown"

            temp_list.append({
                "name": vm.name,
                "resource_group": resource_group,
                "location": vm.location,
                "size": vm.hardware_profile.vm_size,
                "os_type": vm.storage_profile.os_disk.os_type.value,
                "status": status
            })

        vm_cache = temp_list
    except Exception as e:
        vm_cache = [{"error": str(e)}]
    finally:
        is_loading = False


@app.route("/")
def home():
    return render_template("index.html")


@app.route("/api/vms")
def api_vms():
    """Return cached VM data immediately; trigger background refresh if needed."""
    global vm_cache, is_loading

    if not vm_cache and not is_loading:
        threading.Thread(target=fetch_vm_inventory, daemon=True).start()
        return jsonify({"status": "loading", "message": "Fetching VM inventory. Please refresh in a few seconds."})

    if is_loading:
        return jsonify({"status": "loading", "message": "Still fetching VM inventory. Please refresh."})

    return jsonify(vm_cache)


# No app.run() here because Azure uses Gunicorn
