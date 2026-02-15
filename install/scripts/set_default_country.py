#!/usr/bin/env python3
"""
Set default country for companies and for new contacts (ORM, after base init).

1. res.company.country_id: set country for all companies by ISO code.
2. ir.default for res.partner.country_id: so any new contact created in the UI
   has this country pre-filled (global default; existing contacts unchanged).

Run with Odoo's Python and PYTHONPATH=$ODOO_HOME. Uses env: ODOO_CONF, DB_NAME,
ODOO_COUNTRY_CODE (default PA).
"""
from __future__ import annotations

import contextlib
import os
import sys

# Require env
ODOO_CONF = os.environ.get("ODOO_CONF")
DB_NAME = os.environ.get("DB_NAME")
COUNTRY_CODE = (os.environ.get("ODOO_COUNTRY_CODE") or "PA").strip().upper()

if not ODOO_CONF or not DB_NAME:
    print("ERROR: ODOO_CONF and DB_NAME must be set.", file=sys.stderr)
    sys.exit(1)

# Bootstrap Odoo: repo is at ODOO_HOME/odoo, Python package at ODOO_HOME/odoo/odoo/
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

# Get registry: Odoo 19 may not expose odoo.registry on main module; try submodule then sql_db
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
    country = env["res.country"].search([("code", "=", COUNTRY_CODE)], limit=1)
    if not country:
        print(f"WARNING: Country with code '{COUNTRY_CODE}' not found. Skipping.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    # 1) Set country for all companies (res.company.country_id)
    companies = env["res.company"].search([])
    companies.write({"country_id": country.id})
    print(f"Set default country to {country.name} ({COUNTRY_CODE}) for {len(companies)} company(ies).")

    # 2) Set global default for new contacts (res.partner.country_id) via ir.default.
    #    New contacts created in the UI will have this country pre-filled; existing
    #    contacts are unchanged. user_id=False, company_id=False => global default.
    env["ir.default"].set(
        "res.partner",
        "country_id",
        country.id,
        user_id=False,
        company_id=False,
    )
    print(f"Set ir.default for res.partner.country_id to {country.name} ({COUNTRY_CODE}) (global).")

    cr.commit()
