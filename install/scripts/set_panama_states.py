#!/usr/bin/env python3
"""
Load Panama provinces and comarcas into res.country.state (code PA-01 .. PA-13, name).

Creates or updates res.country.state for country PA with:
  code = 01, 02, ... 13
  name = Bocas del Toro, Coclé, Colón, etc.

Run after base (and ideally l10n_pa) is installed. Uses same env as set_default_country.py:
ODOO_CONF, DB_NAME, ODOO_HOME. Optional: ODOO_COUNTRY_CODE (default PA).
"""
from __future__ import annotations

import contextlib
import os
import sys

ODOO_CONF = os.environ.get("ODOO_CONF")
DB_NAME = os.environ.get("DB_NAME")
COUNTRY_CODE = (os.environ.get("ODOO_COUNTRY_CODE") or "PA").strip().upper()

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

# Code (PA-XX) -> Name (province/comarca)
PANAMA_STATES = [
    ("01", "Bocas del Toro"),
    ("02", "Coclé"),
    ("03", "Colón"),
    ("04", "Chiriquí"),
    ("05", "Darién"),
    ("06", "Herrera"),
    ("07", "Los Santos"),
    ("08", "Panamá"),
    ("09", "Veraguas"),
    ("10", "Panamá Oeste"),
    ("11", "Comarca Emberá Wounaan"),
    ("12", "Comarca Kuna Yala (Guna Yala)"),
    ("13", "Comarca Ngäbe-Buglé"),
]

with cr_context as cr:
    env = api.Environment(cr, odoo.SUPERUSER_ID, {})

    if "res.country.state" not in env:
        print("WARNING: res.country.state not available. Skipping.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    country = env["res.country"].search([("code", "=", COUNTRY_CODE)], limit=1)
    if not country:
        print(f"WARNING: Country {COUNTRY_CODE} not found. Skipping.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    State = env["res.country.state"]
    created = 0
    updated = 0

    for code, name in PANAMA_STATES:
        state = State.search(
            [
                ("country_id", "=", country.id),
                ("code", "=", code),
            ],
            limit=1,
        )
        if state:
            if state.name != name:
                state.name = name
                updated += 1
                print(f"Updated state {code} -> {name}")
        else:
            State.create(
                {
                    "country_id": country.id,
                    "code": code,
                    "name": name,
                }
            )
            created += 1
            print(f"Created state {code} -> {name}")

    cr.commit()
    print(f"Done. Created {created}, updated {updated} states for {country.name} ({COUNTRY_CODE}).")
