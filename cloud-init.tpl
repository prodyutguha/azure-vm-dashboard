#cloud-config
package_update: true
packages:
  - python3
  - python3-pip

runcmd:
  - pip3 install flask gunicorn azure-identity azure-mgmt-compute
  - mkdir -p /opt/az-webapp
  - bash -lc 'cat >/opt/az-webapp/app.py << "PYCODE"
from flask import Flask, jsonify, render_template_string
from azure.identity import ManagedIdentityCredential, DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient
import os

app = Flask(__name__)

RG_NAME = "${rg_name}"

HTML = """
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Azure VM Dashboard</title>
  <style>
    body { font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto; padding: 20px; }
    h1 { margin: 0 0 10px 0; }
    .meta { color:#444; margin-bottom: 16px; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 8px; }
    th { text-align: left; background: #f6f6f6; }
    tr:hover { background: #fafafa; }
    .pill { display:inline-block; padding:2px 8px; border-radius:999px; background:#eef; }
  </style>
  <meta http-equiv="refresh" content="60">
</head>
<body>
  <h1>Azure VM Dashboard</h1>
  <div class="meta">Resource Group: <b>{{ rg }}</b> • Auto-refresh: 60s</div>
  <table>
    <thead>
      <tr><th>Name</th><th>Location</th><th>Size</th><th>Provisioning</th><th>Power State</th></tr>
    </thead>
    <tbody>
    {% for vm in vms %}
      <tr>
        <td>{{ vm["name"] }}</td>
        <td>{{ vm["location"] }}</td>
        <td>{{ vm["size"] }}</td>
        <td>{{ vm["provisioning_state"] }}</td>
        <td>{{ vm["power_state"] }}</td>
      </tr>
    {% endfor %}
    </tbody>
  </table>
  <p class="meta">API: <a href="/api/vms">/api/vms</a></p>
</body>
</html>
"""

def get_compute_client():
    # Managed Identity is preferred in Azure VMs
    cred = ManagedIdentityCredential()
    # Discover subscription id via IMDS (env injected automatically for MSI-aware libs not guaranteed)
    # Fallback to DefaultAzureCredential if needed.
    try:
        client = ComputeManagementClient(cred, os.environ.get("AZURE_SUBSCRIPTION_ID", ""))
        if not client.config.subscription_id:
            raise ValueError("No subscription id found in environment")
        return client
    except Exception:
        cred2 = DefaultAzureCredential()
        sub = os.popen("curl -sH Metadata:true 'http://169.254.169.254/metadata/instance/compute/subscriptionId?api-version=2021-02-01&format=text'").read().strip()
        return ComputeManagementClient(cred2, sub)

def list_vms_in_rg(rg):
    client = get_compute_client()
    vms = []
    for vm in client.virtual_machines.list(rg):
        instance_view = client.virtual_machines.instance_view(rg, vm.name)
        power = "unknown"
        for s in instance_view.statuses or []:
            if s.code and s.code.startswith("PowerState/"):
                power = s.code.split("/",1)[1]
        vms.append({
            "name": vm.name,
            "location": vm.location,
            "size": (vm.hardware_profile.vm_size if vm.hardware_profile else ""),
            "provisioning_state": (vm.provisioning_state or "unknown"),
            "power_state": power
        })
    vms.sort(key=lambda x: x["name"])
    return vms

@app.route("/api/vms")
def api_vms():
    return jsonify(list_vms_in_rg(RG_NAME))

@app.route("/")
def home():
    vms = list_vms_in_rg(RG_NAME)
    return render_template_string(HTML, vms=vms, rg=RG_NAME)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PYCODE'
  - bash -lc 'cat >/etc/systemd/system/az-webapp.service << "UNIT"
[Unit]
Description=Azure VM Dashboard (Flask via Gunicorn)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/az-webapp
ExecStart=/usr/bin/gunicorn --bind 0.0.0.0:80 app:app
Restart=always
RestartSec=3
# Gunicorn uses the default Python site-packages (pip3 installed globally)

[Install]
WantedBy=multi-user.target
UNIT'
  - systemctl daemon-reload
  - systemctl enable --now az-webapp.service
