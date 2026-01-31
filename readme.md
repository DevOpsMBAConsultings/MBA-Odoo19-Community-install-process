# MBA – Odoo 19 Community Install Process (v2)

Standardized, repeatable installation process for **Odoo 19 Community** on **Ubuntu 24.04**.

## 🎯 Objective
- Install Odoo 19 Community in a clean, controlled way
- Reusable for Oracle Cloud, local servers, customer environments
- Reduce installation time and avoid manual drift

## ✅ What v2 includes
- Deterministic install flow with numbered scripts under `/install`
- Python venv + dependency install compatible with Ubuntu 24.04 (PEP 668 safe)
- Odoo config generated from templates
- systemd service creation and auto-start
- Optional demo access: open port **8069** only if `ALLOW_ODOO_PORT=1`
- Nginx reverse proxy + Let’s Encrypt SSL
- Post-install health check + summary

## ⚠️ Important
This repo does **NOT** store passwords or secrets.
Sensitive values are generated locally on each server.

Maintained by **MBA Consultings**  
https://mbaconsultings.com

---

# ✅ Install (Ubuntu 24.04) with port 8069 closed (recommended)

Run on a **fresh Ubuntu 24.04 server**:

```bash
sudo apt update -y && sudo apt install -y git
git clone -b v2 https://github.com/DevOpsMBAConsultings/MBA-Odoo19-Community-install-process.git
cd MBA-Odoo19-Community-install-process
chmod +x install.sh install/*.sh post/*.sh
sudo ./install.sh