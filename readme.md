Got it. Below is the corrected and final README.md for v2, faithful to the original structure (two install options), but updated to reflect all v2 features, behavior, and version pinning.

This is one complete file. Copy–paste it into README.md on branch v2.

⸻

MBA – Odoo Community Install Process (v2)

This repository contains a standardized, interactive, and repeatable installation process
for Odoo Community on Ubuntu 24.04, starting with Odoo 19.

This README applies to branch v2 only

⸻

🎯 Objective
	•	Install Odoo Community in a clean, controlled, production-ready way
	•	Support multiple Odoo versions (starting with 19)
	•	Make the process reusable for:
	•	Oracle Cloud
	•	Local servers
	•	Customer environments
	•	Reduce installation time from hours to minutes
	•	Avoid configuration drift and manual fixes
	•	Make the installer usable by any engineer, any day

⸻

🧱 What v2 provides

✅ Interactive installer

The script asks at runtime for:
	•	Odoo version to install (default: latest supported)
	•	Domain name (for Nginx)
	•	Email address (for SSL / Certbot)

✅ Deterministic database naming
	•	Database is automatically created
	•	Database name follows the version:
	•	odoo19
	•	odoo18
	•	etc.

✅ Correct Python & venv handling (Ubuntu 24.04 safe)
	•	Dedicated virtual environment per Odoo version
	•	All required Python dependencies installed correctly
	•	Avoids externally-managed-environment (PEP 668) issues

✅ Nginx reverse proxy (optional)
	•	Automatic Nginx configuration
	•	Reverse proxy to Odoo (127.0.0.1:8069)
	•	SSL-ready (Certbot-compatible)

✅ Version-aware system layout
	•	/opt/odoo/odoo<version>/
	•	/etc/odoo<version>.conf
	•	/etc/systemd/system/odoo<version>.service

⸻

🚀 Target audience
	•	MBA Consultings internal team
	•	DevOps / ERP implementations
	•	Consultants deploying Odoo Community
	•	Small & medium businesses using Odoo

⸻

⚠️ Security note

This repository does NOT store passwords or secrets.
All sensitive values are generated or requested locally at install time.

⸻

📦 Supported OS
	•	Ubuntu 24.04 LTS (required)

⸻

✅ Install (Ubuntu 24.04) with port 8069 closed (Nginx only)

Run the following commands on a fresh Ubuntu 24.04 server:

sudo apt update -y && sudo apt install -y git
git clone -b v2 https://github.com/DevOpsMBAConsultings/MBA-Odoo19-Community-install-process.git
cd MBA-Odoo19-Community-install-process
chmod +x install.sh install/*.sh scripts/*.sh post/*.sh
sudo ./install.sh


⸻

✅ Install (Ubuntu 24.04) with port 8069 open

Run the following commands on a fresh Ubuntu 24.04 server:

sudo apt update -y && sudo apt install -y git
git clone -b v2 https://github.com/DevOpsMBAConsultings/MBA-Odoo19-Community-install-process.git
cd MBA-Odoo19-Community-install-process
chmod +x install.sh install/*.sh scripts/*.sh post/*.sh
sudo ALLOW_ODOO_PORT=1 ./install.sh


⸻

🧠 What the installer will ask you

During execution, the script will prompt for:
	1.	Odoo version
	•	Default: latest supported (e.g. 19)
	2.	Domain name
	•	Example: trucksolutiongp.mbaconsultings.com
	3.	Email address
	•	Used for SSL / Certbot
	•	Example: info@mbaconsultings.com

⸻

📁 Resulting layout (example: Odoo 19)

/opt/odoo/
 └── odoo19/
     ├── odoo/
     ├── venv/
     └── custom-addons/

/etc/odoo19.conf
/etc/systemd/system/odoo19.service
/var/log/odoo/odoo19.log
/var/lib/odoo


⸻

🔁 Versioning policy
	•	main → stable reference
	•	v2 → current active installer
	•	Future versions:
	•	v3, v4, etc.
	•	Each branch has its own README
	•	Each README clones its own branch

⸻

🧪 Testing philosophy

v2 is designed so that you can:
	•	Destroy a server
	•	Recreate it
	•	Re-run the installer
	•	Get the same result every time

⸻

Maintained by MBA Consultings
https://mbaconsultings.com
