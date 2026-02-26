#!/usr/bin/env python3
"""
Set default paper format to US Letter with 5mm upper and lower margins.

By default Odoo might use Euro (A4) or US Letter with larger margins.
This script sets the primary paperformats (base.paperformat_us and base.paperformat_euro)
to US Letter with 5mm top and bottom margins, and ensures the active companies use US Letter.

Run after base is installed. Uses ODOO_CONF, DB_NAME, ODOO_HOME.
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

with cr_context as cr:
    env = api.Environment(cr, odoo.SUPERUSER_ID, {})

    if "report.paperformat" not in env:
        print("WARNING: report.paperformat not found. Skipping.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    # We update both base paperformats to be safe, or just check the company's paperformat
    us_format = env.ref('base.paperformat_us', raise_if_not_found=False)
    euro_format = env.ref('base.paperformat_euro', raise_if_not_found=False)

    for pf in [us_format, euro_format]:
        if pf:
            pf.write({
                'format': 'Letter',
                'margin_top': 5.0,
                'margin_bottom': 5.0,
            })
            print(f"Updated paperformat '{pf.name}' to Letter with 5mm margins (ID: {pf.id}).")

    # Update company default paper formats
    companies = env["res.company"].search([])
    for company in companies:
        if company.paperformat_id:
            company.paperformat_id.write({
                'format': 'Letter',
                'margin_top': 5.0,
                'margin_bottom': 5.0,
            })
            print(f"Updated assigned paperformat for company '{company.name}'.")
        elif us_format:
            company.paperformat_id = us_format.id
            print(f"Assigned US Letter paperformat to company '{company.name}'.")

    cr.commit()
    print("Done. Default paper format configured.")
