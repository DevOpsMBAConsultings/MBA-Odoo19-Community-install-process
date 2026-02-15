# MBA – Odoo 19 Community Install Process

Standardized, repeatable installation process for **Odoo 19 Community** on **Ubuntu 24.04**.

## 🎯 Objective
- Install Odoo 19 Community in a clean, controlled way
- Reusable for Oracle Cloud, local servers, customer environments
- Reduce installation time and avoid manual drift

## ✅ What this includes
- Deterministic install flow with numbered scripts under `/install`
- Python venv + dependency install compatible with Ubuntu 24.04 (PEP 668 safe)
- Odoo config generated from templates
- systemd service creation and auto-start
- Optional demo access: open port **8069** only if `ALLOW_ODOO_PORT=1`
- Nginx reverse proxy + Let’s Encrypt SSL
- Post-install health check + summary

## 🌐 Idioma, país y módulos (opcional)

Al inicializar la base de datos (`09_init_database.sh`) se pueden usar estas variables de entorno:

| Variable | Por defecto | Descripción |
|----------|-------------|-------------|
| `ODOO_LANG` | `es_PA` | Código de idioma (ej. `es_ES`, `en_US`). |
| `ODOO_COUNTRY_CODE` | `PA` | País por defecto de la empresa (código ISO, ej. `PA`, `US`). |
| `ODOO_INIT_MODULES` | *(auto)* | Si no se define: se instalan **todos** los add-ons en `custom-addons`. Si se define: solo esa lista (separada por comas). |
| `ODOO_EXTRA_MODULES` | `sale,purchase,crm,stock,contacts,account` | Módulos **estándar de Odoo** a instalar además. Por defecto: Ventas, Compras, CRM, Inventario, Contactos, Contabilidad. Definir vacío para no instalar ninguno. |

### Gestión de Módulos (Add-ons) con Git

El sistema de add-ons ha sido modernizado para usar repositorios de Git en lugar de archivos ZIP, permitiendo una gestión más flexible y segura.

- **Archivo de Repositorios (`custom_addons.txt`):** Este es el archivo principal donde se define qué módulos instalar. Cada línea debe ser la URL de un repositorio de Git que se clonará en la carpeta `/opt/odoo/custom-addons/`.

- **Manejo de Secretos (`config/token.txt`):** Para clonar repositorios privados (por ejemplo, desde GitHub), el sistema necesita un token de acceso.
  1.  Copia tu token de acceso personal de GitHub.
  2.  Pégalo dentro del archivo `config/token.txt`.
  3.  Este archivo está ignorado por Git (`.gitignore`), por lo que tu token nunca se subirá al repositorio público.

- **Cómo añadir repositorios en `custom_addons.txt`:**
  - **Repositorios Públicos:** Simplemente añade la URL completa.
    ```
    https://github.com/OCA/web.git
    ```
  - **Repositorios Privados:** Usa el placeholder especial `your-github-token`. El script lo reemplazará automáticamente con el token de `config/token.txt`.
    ```
    https://your-github-token@github.com/DevOpsMBAConsultings/facturacion_electronica.git
    ```

- **Instalación de Módulos:** El proceso de instalación (`09_init_database.sh`) sigue funcionando igual. Por defecto, instalará **todos** los módulos que se encuentren en los repositorios clonados dentro de `custom-addons`, además de los módulos estándar definidos en `ODOO_EXTRA_MODULES`. Puedes restringir qué módulos custom se instalan usando la variable `ODOO_INIT_MODULES`.

---
# ✅ Métodos de Instalación (Ubuntu 24.04)

Elige el flujo de trabajo que mejor se adapte a tus necesidades.

---
### Flujo A: Clonar directamente en el Servidor (Recomendado para Producción)

Este método es ideal para un despliegue rápido en un servidor nuevo.

1.  **Conéctate al servidor por SSH.**

2.  **Clona el repositorio:**
    ```bash
    sudo apt update -y && sudo apt install -y git
    git clone https://github.com/DevOpsMBAConsultings/MBA-Odoo19-Community-install-process.git
    cd MBA-Odoo19-Community-install-process
    ```

3.  **Configura tus módulos y token (si usas repositorios privados):**
    - **Edita la lista de módulos:** `nano custom_addons.txt`
    - **Añade tu token de GitHub:** `echo "tu-token-aqui" > config/token.txt`

4.  **Ejecuta el instalador:**
    ```bash
    chmod +x install.sh install/*.sh post/*.sh
    sudo ./install.sh
    ```
---
### Flujo B: Desarrollo Local y Copia al Servidor (Recomendado para Desarrolladores)

Usa este método para probar cambios locales en los scripts sin necesidad de hacer `git push`.

1.  **Prepara tu entorno local:**
    - Asegúrate de que tu token de GitHub está en `config/token.txt`.
    - Edita `custom_addons.txt` según necesites.

2.  **Abre un terminal en tu máquina local** y navega a la carpeta que contiene el proyecto (ej. `cd ~/Development/mba-odoo-addons`).

3.  **Copia el proyecto al servidor** (reemplaza `USUARIO` y `IP_DEL_SERVIDOR`):
    ```bash
    scp -r MBA-Odoo19-Community-install-process USUARIO@IP_DEL_SERVIDOR:~/
    ```

4.  **Ejecuta el instalador remotamente** desde tu máquina local:
    ```bash
    ssh USUARIO@IP_DEL_SERVIDOR "cd MBA-Odoo19-Community-install-process && chmod +x install.sh install/*.sh post/*.sh && sudo ./install.sh"
    ```