# SSL certificates con Cloudflare R2

Pasos para usar **Cloudflare R2** como almacén de certificados SSL (restore + backup automático en cada instalación).

---

## 1. Crear el bucket en Cloudflare

1. Entra en [Cloudflare Dashboard](https://dash.cloudflare.com) → **R2 Object Storage**.
2. **Create bucket**.
3. Nombre del bucket, por ejemplo: `odoo-ssl-certs`.
4. Crear. (Región no es crítica para R2.)

---

## 2. Crear un API token para R2

1. En R2, ve a **Manage R2 API Tokens** (o **Overview** → **Manage R2 API Tokens**).
2. **Create API token**.
3. Nombre, ej.: `odoo-ssl-backup`.
4. Permisos: **Object Read & Write** (o al menos para el bucket que creaste).
5. Opcional: restringe por bucket (`odoo-ssl-certs`).
6. **Create API Token**.
7. **Copia y guarda**:
   - **Access Key ID**
   - **Secret Access Key**  
   (el secreto solo se muestra una vez).

---

## 3. Obtener tu Account ID

- En el Dashboard de Cloudflare, en la barra lateral derecha suele aparecer **Account ID**.
- O en la URL al estar en R2: `dash.cloudflare.com/.../r2?account_id=XXXXXXXX`.

Sustituye `YOUR_ACCOUNT_ID` por ese valor en el endpoint.

---

## 4. Variables de entorno para el script

En tu máquina (o en el servidor donde corres el instalador), define **antes** de ejecutar `install.sh` o el paso `install/11_ngnix.sh`:

```bash
export ODOO_SSL_STORAGE=s3
export ODOO_SSL_S3_BUCKET=odoo-ssl-certs
export ODOO_SSL_S3_PREFIX=odoo-ssl
export ODOO_SSL_S3_ENDPOINT_URL=https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com
export AWS_ACCESS_KEY_ID=tu_access_key_id_del_paso_2
export AWS_SECRET_ACCESS_KEY=tu_secret_access_key_del_paso_2
```

Sustituye:

- `YOUR_ACCOUNT_ID` → tu Account ID de Cloudflare.
- `tu_access_key_id_del_paso_2` → Access Key ID del API token.
- `tu_secret_access_key_del_paso_2` → Secret Access Key del API token.

Opcional: si usas otro nombre de bucket, cambia `ODOO_SSL_S3_BUCKET`.

---

## 5. Ejecutar la instalación

Desde el repo del instalador:

```bash
cd MBA-Odoo19-Community-install-process
# Cargar las variables (o pegarlas en la misma sesión)
source config/ssl-storage.env.example   # si ya lo copiaste y editaste
# O export manual como en el paso 4

sudo -E ./install.sh
```

O solo el paso de Nginx + SSL:

```bash
export DOMAIN=dev1.mbaconsultings.com
export LETSENCRYPT_EMAIL=info@mbaconsultings.com
# + las variables R2 del paso 4
sudo -E bash install/11_ngnix.sh
```

El script:

- Intentará **restaurar** `odoo-ssl/<tu-dominio>/cert.tar.gz` desde R2.
- Si no existe o no es válido, pedirá certificado con Certbot y **subirá** ese `.tar.gz` a R2.
- En la próxima vez que provisiones un servidor (mismo dominio), usará el cert de R2 y no gastará rate limit de Let's Encrypt.

---

## 6. Dónde se guarda el cert en R2

Ruta en el bucket:

```
odoo-ssl/<DOMAIN>/cert.tar.gz
```

Ejemplo: dominio `dev1.mbaconsultings.com` → objeto `odoo-ssl/dev1.mbaconsultings.com/cert.tar.gz`.

---

## Seguridad

- No subas `config/ssl-storage.env.example` con secretos al repo. Usa un `.env` local o variables en tu entorno/CI.
- El API token puede tener permiso solo de lectura/escritura en ese bucket (o solo en el prefijo `odoo-ssl/`).
