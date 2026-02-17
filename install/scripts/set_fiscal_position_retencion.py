#!/usr/bin/env python3
"""
Create fiscal position "Retención de impuestos" (tax withholding).

1. For each company: find or create account.fiscal.position with name "Retención de impuestos".
2. auto_apply is configurable via ODOO_FISCAL_POSITION_RETENCION_AUTO_APPLY (default 0 = False;
   set to 1 to enable Detectar de forma automática).

Run after accounting (and l10n if needed) is installed. Uses ODOO_CONF, DB_NAME, ODOO_HOME.
"""
from __future__ import annotations

import contextlib
import os
import sys

ODOO_CONF = os.environ.get("ODOO_CONF")
DB_NAME = os.environ.get("DB_NAME")
FP_NAME = (os.environ.get("ODOO_FISCAL_POSITION_RETENCION_NAME") or "Retención de impuestos").strip()
AUTO_APPLY = os.environ.get("ODOO_FISCAL_POSITION_RETENCION_AUTO_APPLY", "1").strip() in ("1", "true", "yes")

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
            if fp.auto_apply != AUTO_APPLY:
                fp.auto_apply = AUTO_APPLY
                print(f"Updated '{FP_NAME}' auto_apply={AUTO_APPLY} in company {company.name}.")
            else:
                print(f"Fiscal position '{FP_NAME}' already exists in company {company.name}.")
        else:
            FiscalPosition.create(
                {
                    "name": FP_NAME,
                    "company_id": company.id,
                    "auto_apply": AUTO_APPLY,
                }
            )
            print(f"Created fiscal position '{FP_NAME}' for company {company.name} (auto_apply={AUTO_APPLY}).")

    cr.commit()
    print("Done. Fiscal position 'Retención de impuestos' is available.")
