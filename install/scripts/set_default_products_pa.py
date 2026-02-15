#!/usr/bin/env python3
"""
Create default service products for Panama if missing.

Creates three services with 0%% tax (Exento):
  - Servicio de Acarreo
  - Otros Gastos
  - Seguro

Uses the 0%% sale and purchase taxes created by set_default_taxes_pa.py.
Run after sale/product and set_default_taxes_pa. Uses ODOO_CONF, DB_NAME, ODOO_HOME, ODOO_COUNTRY_CODE (default PA).
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

# Service product names to create (all with 0% tax)
PRODUCT_NAMES = [
    "Servicio de Acarreo",
    "Otros Gastos",
    "Seguro",
]

with cr_context as cr:
    env = api.Environment(cr, odoo.SUPERUSER_ID, {})

    if "product.template" not in env:
        print("WARNING: product module not installed. Skipping default products.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    if "account.tax" not in env:
        print("WARNING: account module not installed. Run set_default_taxes_pa.py first.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    ProductTemplate = env["product.template"]
    Tax = env["account.tax"]
    country = env["res.country"].search([("code", "=", COUNTRY_CODE)], limit=1)
    if not country:
        print(f"WARNING: Country {COUNTRY_CODE} not found. Skipping.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    companies = env["res.company"].search([])
    created = 0

    for company in companies:
        fiscal_country = company.account_fiscal_country_id or company.country_id
        if fiscal_country and fiscal_country.code != COUNTRY_CODE:
            continue

        # Find 0% sale and purchase taxes for this company
        tax_sale = Tax.search(
            [
                ("company_id", "=", company.id),
                ("country_id", "=", country.id),
                ("type_tax_use", "=", "sale"),
                ("amount", "=", 0.0),
                ("amount_type", "=", "percent"),
            ],
            limit=1,
        )
        tax_purchase = Tax.search(
            [
                ("company_id", "=", company.id),
                ("country_id", "=", country.id),
                ("type_tax_use", "=", "purchase"),
                ("amount", "=", 0.0),
                ("amount_type", "=", "percent"),
            ],
            limit=1,
        )
        if not tax_sale:
            print(f"WARNING: 0%% sale tax not found for company {company.name}. Run set_default_taxes_pa.py first.", file=sys.stderr)
            continue
        if not tax_purchase:
            print(f"WARNING: 0%% purchase tax not found for company {company.name}. Run set_default_taxes_pa.py first.", file=sys.stderr)
            continue

        for name in PRODUCT_NAMES:
            existing = ProductTemplate.search(
                [
                    ("company_id", "in", (False, company.id)),
                    ("name", "=", name),
                ],
                limit=1,
            )
            if existing:
                continue
            ProductTemplate.create({
                "name": name,
                "type": "service",
                "taxes_id": [(6, 0, [tax_sale.id])],
                "supplier_taxes_id": [(6, 0, [tax_purchase.id])],
                "company_id": company.id,
            })
            created += 1
            print(f"Created product '{name}' (service, 0%% tax) for company {company.name}.")

    cr.commit()
    print(f"Done. {created} default service product(s) created.")
