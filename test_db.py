import sys
import os

ODOO_CONF = os.environ.get("ODOO_CONF", "/etc/odoo19/odoo.conf")
DB_NAME = os.environ.get("DB_NAME", "odoo19")

sys.path.insert(0, "/opt/odoo/odoo")
import odoo
from odoo import api, SUPERUSER_ID

odoo.tools.config.parse_config(["-c", ODOO_CONF])
registry = odoo.registry(DB_NAME)

with registry.cursor() as cr:
    env = api.Environment(cr, SUPERUSER_ID, {})
    Tax = env["account.tax"]
    print(Tax._fields['tax_ids'])
