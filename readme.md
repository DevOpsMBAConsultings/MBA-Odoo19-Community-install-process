---

## 🔐 Firewall & port behavior

By default:
- **Port 8069 is NOT exposed publicly**
- Odoo is accessed through **Nginx (port 80 / 443)**

If you explicitly want port `8069` open:
- Use the environment flag `ALLOW_ODOO_PORT=1`

---

## 🚀 Installation (Ubuntu 24.04)

### Default install (recommended – port 8069 closed)

```bash
sudo apt update -y && sudo apt install -y git
git clone https://github.com/DevOpsMBAConsultings/MBA-Odoo19-Community-install-process.git
cd MBA-Odoo19-Community-install-process
chmod +x install.sh install/*.sh post/*.sh
sudo ./install.sh