# Configuración de Nginx en Gateway para Odoo 18

En instalaciones recientes de Odoo 18 automatizadas con este script, **Nginx no se instala localmente** en el servidor de Odoo. En su lugar, el acceso a Odoo debe ser manejado mediante un **Reverse Proxy (ej. Nginx)** ubicado en un Gateway externo o servidor frontal.

## Puertos Importantes en Odoo 18

- **8069**: Puerto HTTP estándar para la aplicación web y llamadas API (REST/XML-RPC).
- **8072**: Puerto para el servidor ASGI (WebSockets), fundamental para Live-chat, notificaciones en tiempo real ("Discuss") y eventos asíncronos. **Si este puerto no se redirige correctamente, la interfaz mostrará el error de "Se perdió la conexión en tiempo real..."**.

## Configuración Recomendada de Nginx (Reverse Proxy)

En el servidor Gateway, crea el archivo de configuración para el sitio web (por ejemplo, `/etc/nginx/sites-available/odoo18.midominio.com`):

```nginx
server {
    server_name odoo18.midominio.com;

    # Logs
    access_log /var/log/nginx/odoo18.access.log;
    error_log /var/log/nginx/odoo18.error.log;

    # Bloquear acceso a la selección de base de datos si es necesario
    location ~ ^/web/database/(manager|selector) {
        deny all;
    }

    # Redirección estándar HTTP (puerto 8069)
    location / {
        proxy_pass http://<IP_PRIVADA_ODOO>:8069;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Redirección de WebSockets (Chat/Notificaciones en tiempo real) (puerto 8072)
    location /websocket {
        proxy_pass http://<IP_PRIVADA_ODOO>:8072;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Resto de la configuración SSL (Let's Encrypt / Certbot la añadirá automáticamente)
    listen 80;
}
```

**Pasos post-configuración:**
1. Reemplaza `<IP_PRIVADA_ODOO>` con la IP interna del servidor donde corriste el script de instalación (ej. `10.0.1.113`).
2. Habilita el sitio: `sudo ln -s /etc/nginx/sites-available/odoo18.midominio.com /etc/nginx/sites-enabled/`
3. Genera certificados SSL: `sudo certbot --nginx -d odoo18.midominio.com`
4. Reinicia Nginx: `sudo systemctl reload nginx`
