#!/usr/bin/env python3
"""
Create fiscal position "Exento de impuestos" with "Detectar de forma automática" (auto_apply) enabled.

1. For each company: find or create account.fiscal.position with name "Exento de impuestos".
2. Set auto_apply=True so Odoo can apply it automatically when criteria match (e.g. country / tax ID).

Run after accounting (and l10n if needed) is installed. Uses same env as set_default_country.py:
ODOO_CONF, DB_NAME, ODOO_HOME.
"""
from __future__ import annotations

import contextlib
import os
import sys

ODOO_CONF = os.environ.get("ODOO_CONF")
DB_NAME = os.environ.get("DB_NAME")
FP_NAME = (os.environ.get("ODOO_FISCAL_POSITION_NAME") or "Exento de impuestos").strip()

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

    if "account.fiscal.position" not in env:
        print("WARNING: account module not installed. Skipping fiscal position.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    FiscalPosition = env["account.fiscal.position"]
    companies = env["res.company"].search([])

    for company in companies:
        fp = FiscalPosition.search(
            [
                ("company_id", "=", company.id),
                ("name", "=", FP_NAME),
            ],
            limit=1,
        )
        if fp:
            if not fp.auto_apply:
                fp.auto_apply = True
                print(f"Enabled 'Detectar de forma automática' for '{FP_NAME}' in company {company.name}.")
            else:
                print(f"Fiscal position '{FP_NAME}' already exists with auto_apply in company {company.name}.")
        else:
            fp = FiscalPosition.create(
                {
                    "name": FP_NAME,
                    "company_id": company.id,
                    "auto_apply": True,
                }
            )
            print(f"Created fiscal position '{FP_NAME}' with Detectar de forma automática for company {company.name}.")

    cr.commit()
    print("Done. Fiscal position 'Exento de impuestos' is available with automatic detection enabled.")
