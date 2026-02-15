# Cloudflare R2: datos para el script de instalación

Sigue estos pasos **una sola vez** en tu cuenta de Cloudflare. Al terminar tendrás todo lo que el script te pedirá (o podrás exportar las variables tú mismo).

---

## Paso 1: Entrar a R2

1. En el **Dashboard de Cloudflare** (barra lateral izquierda), entra a **R2 Object Storage**.
2. Si es la primera vez, puede que te pida activar R2 (es gratis en el plan).

---

## Paso 2: Anotar tu Account ID

Lo necesitas para el **endpoint** que el script usará.

- En la barra lateral **derecha** del Dashboard suele aparecer **Account ID** (un string alfanumérico).
- O: estando en R2, mira la **URL del navegador**. Verás algo como:
  `https://dash.cloudflare.com/XXXXXXXX/r2/overview`
  Esa **XXXXXXXX** es tu Account ID (puede ser más largo).

**Anótalo aquí:** `________________________________`  
El endpoint será: `https://TU_ACCOUNT_ID.r2.cloudflarestorage.com`

---

## Paso 3: Crear el bucket

1. Dentro de **R2** → **Create bucket**.
2. **Bucket name:** por ejemplo `odoo-ssl-certs` (o el que prefieras).
3. **Create bucket**.

**Anota el nombre del bucket:** `________________________________`

---

## Paso 4: Crear el API token (credenciales)

1. En la misma sección R2, arriba a la derecha → **Manage R2 API Tokens** (o en Overview → enlace a API Tokens).
2. **Create API token**.
3. **Token name:** por ejemplo `odoo-ssl-backup`.
4. **Permissions:** elige **Object Read & Write**.
5. Opcional: en **Specify bucket** elige solo el bucket que creaste (`odoo-ssl-certs`) para limitar el token.
6. **Create API Token**.
7. **Importante:** en la pantalla siguiente se muestran **una sola vez**:
   - **Access Key ID** (ej. `a1b2c3d4e5f6...`)
   - **Secret Access Key** (ej. `xyz123...`)

**Cópialos y guárdalos en un lugar seguro** (gestor de contraseñas o archivo local que no subas al repo).  
Si cierras la ventana sin copiar el Secret, tendrás que crear otro token.

**Anota (o deja en el portapapeles):**
- Access Key ID: `________________________________`
- Secret Access Key: `________________________________`

---

## Paso 5: Resumen para cuando corras el script

Cuando ejecutes `./install.sh` y el script pregunte:

| Pregunta del script | Qué poner (ejemplo) |
|---------------------|----------------------|
| Use remote SSL storage? (s3/url/no) | **s3** |
| S3/R2 bucket name | El nombre del bucket (ej. **odoo-ssl-certs**) |
| S3 endpoint URL | **https://TU_ACCOUNT_ID.r2.cloudflarestorage.com** (sustituye TU_ACCOUNT_ID por el del Paso 2) |
| Access Key ID | El **Access Key ID** del Paso 4 |
| Secret Access Key (hidden) | El **Secret Access Key** del Paso 4 (no se verá al escribir) |

Si prefieres **no** escribir nada durante la instalación, antes de ejecutar el script puedes hacer (sustituye los valores):

```bash
export ODOO_SSL_STORAGE=s3
export ODOO_SSL_S3_BUCKET=odoo-ssl-certs
export ODOO_SSL_S3_ENDPOINT_URL=https://TU_ACCOUNT_ID.r2.cloudflarestorage.com
export AWS_ACCESS_KEY_ID=tu_access_key_id
export AWS_SECRET_ACCESS_KEY=tu_secret_access_key
sudo -E ./install.sh
```

Así el script usará esas variables y no te preguntará por el almacén SSL.

---

## Checklist rápido

- [ ] Account ID anotado
- [ ] Bucket creado (nombre anotado)
- [ ] API token creado; Access Key ID y Secret Access Key guardados
- [ ] Endpoint listo: `https://<Account ID>.r2.cloudflarestorage.com`

Con eso ya tienes la información lista para cuando corras el script de instalación.
