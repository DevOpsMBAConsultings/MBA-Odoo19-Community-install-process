#!/usr/bin/env python3
"""
Enable "Unidades de medida y embalajes" (Units of measure and packaging) in Sales.

Does so by adding the corresponding groups to base.group_user so all internal users
get the feature (same effect as ticking the checkbox in Ventas → Configuración → Ajustes).

Groups enabled:
- uom.group_uom (Units of measure)
- product.group_stock_packaging (Product packaging), if the module is installed

Run after sale (and preferably stock/product) are installed. Uses ODOO_CONF, DB_NAME, ODOO_HOME.
"""
from __future__ import annotations

import contextlib
import os
import sys

ODOO_CONF = os.environ.get("ODOO_CONF")
DB_NAME = os.environ.get("DB_NAME")

if not ODOO_CONF or not DB_NAME:
    print("ERROR: ODOO_CONF and DB_NAME must be set.", file=sys.stderr)
    sys.exit(1)

ODOO_HOME = os.environ.get("ODOO_HOME")
if ODOO_HOME:
    odoo_src = os.path.join(ODOO_HOME, "odoo")
    if os.path.isdir(odoo_src):
        sys.path.insert(0, odoo_src)
    else:
        sys.path.insert(0, ODOO_HOME)

import odoo
from odoo import api, sql_db

odoo.tools.config.parse_config(["-c", ODOO_CONF])

try:
    import odoo.registry as _regmod
    _registry = getattr(_regmod, "registry", None) or getattr(_regmod, "Registry", None)
    if callable(_registry):
        registry = _registry(DB_NAME)
        cr_context = registry.cursor()
    else:
        raise AttributeError("registry")
except (AttributeError, ImportError):
    cr_context = contextlib.closing(sql_db.db_connect(DB_NAME).cursor())

# Groups that correspond to "Unidades de medida y embalajes" in Sales settings.
# Adding them to base.group_user enables the feature for all internal users.
GROUP_XMLIDS = [
    "uom.group_uom",                    # Units of measure
    "product.group_stock_packaging",     # Product packaging (embalajes)
]

with cr_context as cr:
    env = api.Environment(cr, odoo.SUPERUSER_ID, {})

    if "res.groups" not in env:
        print("WARNING: res.groups not found. Skipping.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    base_user = env.ref("base.group_user")
    added = []
    for xmlid in GROUP_XMLIDS:
        try:
            group = env.ref(xmlid)
            if group not in base_user.implied_ids:
                base_user.write({"implied_ids": [(4, group.id)]})
                added.append(group.name)
        except ValueError:
            pass

    cr.commit()
    if added:
        print(f"Enabled for all users: {', '.join(added)}.")
    else:
        print("No additional groups to add (already enabled or modules not installed).")
    print("Done. 'Unidades de medida y embalajes' is enabled in Sales.")
