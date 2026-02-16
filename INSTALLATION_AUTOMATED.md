# Automated Installation Guide - Digifact Modules

Quick guide for installing Digifact modules after using the automated Odoo 19 installation script.

**Repository:** [MBA-Odoo19-Community-install-process](https://github.com/DevOpsMBAConsultings/MBA-Odoo19-Community-install-process/tree/v2)

---

## Prerequisites

- Fresh Ubuntu 24.04 server
- Root or sudo access
- Domain name (for SSL certificate)
- Email address (for Let's Encrypt)

---

## Step 1: Configure Custom Addons

**Before running the installation**, you must add your repositories to `custom_addons.txt`.

```bash
cd ~
rm -rf MBA-Odoo19-Community-install-process
sudo apt update -y && sudo apt install -y git
git clone https://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@github.com/DevOpsMBAConsultings/MBA-Odoo19-Community-install-process.git
```

```bash
cd MBA-Odoo19-Community-install-process
```

1. Edit `custom_addons.txt` and add your repository URLs:
```text
https://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@github.com/DevOpsMBAConsultings/facturacion_electronica.git
```

---

## Step 2: Run Automated Odoo Installation

```bash
chmod +x install.sh install/*.sh post/*.sh
sudo ./install.sh
```

### What You'll Be Asked

1. **Odoo version:** Press Enter (defaults to 19)
2. **Domain name:** Enter your domain (e.g., `erp.yourcompany.com`)
3. **Let's Encrypt email:** Enter your email address

### What It Installs

- ✅ All system dependencies
- ✅ PostgreSQL 14+
- ✅ Odoo 19 Community Edition
- ✅ Python 3.10+ with virtual environment
- ✅ wkhtmltopdf (patched version)
- ✅ Nginx reverse proxy
- ✅ Let's Encrypt SSL certificate
- ✅ Firewall configuration
- ✅ Systemd service

### After Installation

- **Odoo URL:** `https://your-domain.com`
- **Master Password:** Displayed at the end (SAVE IT!)
- **Database:** `odoo19` (auto-created)
- **Custom Addons Path:** `/opt/odoo/custom-addons`

---

## Step 2: Configure Digifact Modules (Automated)

Instead of cloning manually, add your repositories to `custom_addons.txt` **before** running the install script.

1. Edit `custom_addons.txt`:
```text
https://your-github-token@github.com/DevOpsMBAConsultings/l10n_pa_edi_digifact_company.git
https://your-github-token@github.com/DevOpsMBAConsultings/l10n_pa_edi_digifact.git
```

**Replace `<repository-url>` with your actual repository URL.**

### 2.2 Automatic Dependency Installation
The installation script will now automatically:
1. Clone the repositories.
2. Detect if they contain `requirements.txt` and install Python dependencies automatically.
3. Detect valid Odoo modules (scanning subdirectories for `__manifest__.py`) and register them.
4. Attempt to install these modules into the database during initialization.

### 2.3 Restart Odoo (Optional)
The script restarts Odoo automatically, but if you need to do it manually:

```bash
sudo systemctl restart odoo19
```

---

## Step 3: Install Modules in Odoo

1. **Access Odoo:**
   - Open browser: `https://your-domain.com`
   - Log in with admin credentials

2. **Install Base Apps (if not already installed):**
   - Go to **Apps** menu
   - Remove "Apps" filter
   - Install **Invoicing** (Facturación) and **Sales** (if needed)
   - Install **Invoicing** (Technical name: `account`) and **Sales** (`sale`)

3. **Install Digifact Modules (in order):**
   - Go to **Apps** menu
   - Remove "Apps" filter
   - Search for "Panama" or "Digifact"
   - **First:** Install `l10n_pa_edi_digifact_company` (Panama EDI – Company FE Config)
   - **Second:** Install `l10n_pa_edi_digifact` (Panama EDI Digifact)

---

## Step 4: Configure Company FE Settings

1. Go to **Settings** → **Companies** → Select your company
2. Navigate to **Facturación Electrónica** tab
3. Configure:

### Company Identity
- **RUC:** Your company RUC
- **DV (DGI):** Click "Validate RUC" to auto-fill
- **Código de la sucursal:** Branch code (e.g., `0001`)
- **Punto de facturación:** Point of sale (e.g., `001`)

### Location
- **Provincia:** Select province
- **Distrito:** Select district
- **Corregimiento:** Select corregimiento
- **Coordenadas Sucursal:** GPS coordinates (e.g., `+8.9213,-79.7068`)

### Digifact Credentials
- **Usuario Digifact:** Your Digifact username
- **Password Digifact:** Your Digifact password

### Environment
- **Digifact Api Base Url Mode:** 
  - `Sandbox` for testing
  - `Production` for live
- **Digifact Timeout:** 75 seconds (default)

4. **Test Connection:**
   - Click "Test PAC Connection"
   - Should show success

5. **Get Token:**
   - Click "Get PAC Token"
   - Token stored automatically

6. **Save** configuration

---

## Step 5: Verify Installation

### Check Odoo Service

```bash
sudo systemctl status odoo19
```

### Check Logs

```bash
sudo tail -f /var/log/odoo/odoo19.log
```

### Test Invoice Creation

1. Create a test customer with FE fields
2. Create a test invoice
3. Reserve fiscal number
4. Post invoice
5. Send to Digifact (in sandbox mode)

---

## Directory Structure

After installation, your structure should be:

```
/opt/odoo/
├── odoo19/
│   ├── odoo/          # Odoo source code
│   └── venv/          # Python virtual environment
├── custom-addons/
│   ├── l10n_pa_edi_digifact_company/
│   └── l10n_pa_edi_digifact/
└── oca/               # OCA modules (if installed)
```

---

## Configuration Files

- **Odoo Config:** `/etc/odoo19.conf`
- **Systemd Service:** `/etc/systemd/system/odoo19.service`
- **Nginx Config:** `/etc/nginx/sites-available/odoo19`
- **Logs:** `/var/log/odoo/odoo19.log`

---

## Useful Commands

### Service Management

```bash
# Start Odoo
sudo systemctl start odoo19

# Stop Odoo
sudo systemctl stop odoo19

# Restart Odoo
sudo systemctl restart odoo19

# Check Status
sudo systemctl status odoo19

# View Logs
sudo journalctl -u odoo19 -f
```

### Module Management

```bash
# Upgrade module (from command line)
sudo -u odoo /opt/odoo/odoo19/venv/bin/python3 /opt/odoo/odoo19/odoo/odoo-bin -c /etc/odoo19.conf -d odoo19 -u facturacion_electronica --stop-after-init
sudo systemctl start odoo19
```

### Health Check

The automated installation includes a health check script:

```bash
cd /path/to/MBA-Odoo19-Community-install-process
sudo ./post/00_health_check.sh
```

---

## Troubleshooting

### Module Not Found

**Check addons path:**
```bash
grep addons_path /etc/odoo19.conf
```

Should include: `/opt/odoo/custom-addons`

**Restart Odoo:**
```bash
sudo systemctl restart odoo19
```

### Import Errors

**Check logs for missing dependencies:**
The script attempts to install `requirements.txt` from your addons. If an error persists:

```bash
sudo su - odoo
source /opt/odoo/odoo19/venv/bin/activate
# Manually install the missing package
pip install package_name
exit
sudo systemctl restart odoo19
```

### API Connection Issues

**Test connectivity:**
```bash
curl https://testnucpa.digifact.com/api/login/get_token
```

**Check firewall:**
```bash
sudo ufw status
```

**Verify credentials** in company settings.

---

## Next Steps

1. ✅ Complete company FE configuration
2. ✅ Test invoice creation and fiscal number reservation
3. ✅ Test Digifact submission in sandbox
4. ✅ Switch to production environment when ready
5. ✅ Train users on FE workflow

---

## Related Documentation

- **Full Installation Guide:** `INSTALLATION_GUIDE.md`
- **Quick Start:** `QUICK_START.md`
- **API Reference:** `DIGIFACT_API_REFERENCE.md`
- **NUC XML Examples:** `NUC_XML_EXAMPLES_REFERENCE.md`

---

**Automated Installation Script:** [MBA-Odoo19-Community-install-process](https://github.com/DevOpsMBAConsultings/MBA-Odoo19-Community-install-process/tree/v2)
