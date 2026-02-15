#!/usr/bin/env python3
"""
Create tax "Retención de Impuestos" as a tax group (Grupo de impuestos) with the existing 7%
tax in Definición, and assign it to the fiscal position "Retención de impuestos".

1. For each company (fiscal country PA): find or create tax group "Retención de Impuestos".
2. Find existing 7% Ventas tax (e.g. ITBMS 7% Venta) or create one; use as child of the group.
3. Find or create tax "Retención de Impuestos" with amount_type='group', children_tax_ids=[7% tax].
4. Find fiscal position "Retención de impuestos" and add tax mapping: Exento 0% Venta -> Retención de Impuestos.
5. Set the tax's fiscal_position_ids so "Posición fiscal" shows "Retención de impuestos" in the UI.

Run after set_fiscal_position_retencion.py and set_default_taxes_pa.py (and ideally set_itbms_taxes_pa.py).
Uses ODOO_CONF, DB_NAME, ODOO_HOME, ODOO_COUNTRY_CODE (default PA).
"""
from __future__ import annotations

import contextlib
import os
import sys

ODOO_CONF = os.environ.get("ODOO_CONF")
DB_NAME = os.environ.get("DB_NAME")
COUNTRY_CODE = (os.environ.get("ODOO_COUNTRY_CODE") or "PA").strip().upper()
FP_NAME = (os.environ.get("ODOO_FISCAL_POSITION_RETENCION_NAME") or "Retención de impuestos").strip()
TAX_NAME = (os.environ.get("ODOO_TAX_RETENCION_NAME") or "Retención de Impuestos").strip()

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

    # Check if account module is installed
    try:
        TaxModel = env["account.tax"]
        FiscalPositionModel = env["account.fiscal.position"]
    except KeyError as e:
        print(f"ERROR: account module not installed. Missing model: {e}", file=sys.stderr)
        print("Make sure 'account' module is installed before running this script.", file=sys.stderr)
        cr.rollback()
        sys.exit(1)

    country = env["res.country"].search([("code", "=", COUNTRY_CODE)], limit=1)
    if not country:
        print(f"ERROR: Country {COUNTRY_CODE} not found. Make sure the country exists in Odoo.", file=sys.stderr)
        cr.rollback()
        sys.exit(1)

    TaxGroup = env["account.tax.group"]
    Tax = env["account.tax"]
    FiscalPosition = env["account.fiscal.position"]
    companies = env["res.company"].search([])
    
    if not companies:
        print("ERROR: No companies found in the database.", file=sys.stderr)
        cr.rollback()
        sys.exit(1)
    
    print(f"DEBUG: Processing {len(companies)} company/companies for country {COUNTRY_CODE}...", file=sys.stderr)

    for company in companies:
        fiscal_country = company.account_fiscal_country_id or company.country_id
        if fiscal_country and fiscal_country.code != COUNTRY_CODE:
            continue

        # 1) Tax group for Retención
        group = TaxGroup.search(
            [
                ("company_id", "=", company.id),
                ("country_id", "=", country.id),
                ("name", "=", TAX_NAME),
            ],
            limit=1,
        )
        if not group:
            group = TaxGroup.create(
                {
                    "name": TAX_NAME,
                    "company_id": company.id,
                    "country_id": country.id,
                }
            )
            print(f"Created tax group '{TAX_NAME}' for company {company.name}.")

        # 2) 7% Ventas tax (child of group tax) – prefer existing e.g. "ITBMS 7% Venta"
        tax_7 = Tax.search(
            [
                ("company_id", "=", company.id),
                ("country_id", "=", country.id),
                ("type_tax_use", "=", "sale"),
                ("amount", "=", 7.0),
                ("amount_type", "=", "percent"),
            ],
            limit=1,
        )
        if not tax_7:
            tax_7 = Tax.create(
                {
                    "name": "7%",
                    "description": "Retención 7% Venta",
                    "type_tax_use": "sale",
                    "amount_type": "percent",
                    "amount": 7.0,
                    "company_id": company.id,
                    "country_id": country.id,
                    "tax_group_id": group.id,
                }
            )
            print(f"Created 7% sale tax for Retención in company {company.name}.")
        else:
            print(f"Using existing 7% sale tax ({tax_7.description or tax_7.name}) for company {company.name}.")

        # 3) Tax "Retención de Impuestos" (Grupo de impuestos with 7% in Definición)
        retencion_tax = Tax.search(
            [
                ("company_id", "=", company.id),
                ("country_id", "=", country.id),
                ("name", "=", TAX_NAME),
                ("type_tax_use", "=", "sale"),
            ],
            limit=1,
        )
        if not retencion_tax:
            retencion_tax = Tax.create(
                {
                    "name": TAX_NAME,
                    "type_tax_use": "sale",
                    "amount_type": "group",
                    "company_id": company.id,
                    "country_id": country.id,
                    "tax_group_id": group.id,
                    "children_tax_ids": [(6, 0, [tax_7.id])],
                }
            )
            print(f"Created tax '{TAX_NAME}' (Grupo de impuestos with 7%) for company {company.name}.")
        else:
            if retencion_tax.amount_type != "group" or tax_7 not in retencion_tax.children_tax_ids:
                retencion_tax.write(
                    {
                        "amount_type": "group",
                        "tax_group_id": group.id,
                        "children_tax_ids": [(6, 0, [tax_7.id])],
                    }
                )
                print(f"Updated tax '{TAX_NAME}' (group with 7%) for company {company.name}.")

        # 4) Fiscal position "Retención de impuestos": map 0% Venta -> Retención de Impuestos
        fp = FiscalPosition.search(
            [
                ("company_id", "=", company.id),
                ("name", "=", FP_NAME),
            ],
            limit=1,
        )
        if not fp:
            print(f"ERROR: Fiscal position '{FP_NAME}' not found for company {company.name}.", file=sys.stderr)
            print(f"Run set_fiscal_position_retencion.py first to create the fiscal position.", file=sys.stderr)
            cr.rollback()
            sys.exit(1)

        # Source: Exento 0% Venta
        tax_0_sale = Tax.search(
            [
                ("company_id", "=", company.id),
                ("country_id", "=", country.id),
                ("type_tax_use", "=", "sale"),
                ("amount", "=", 0.0),
                ("amount_type", "=", "percent"),
            ],
            limit=1,
        )
        if not tax_0_sale:
            print(f"ERROR: 0% sale tax not found for company {company.name}.", file=sys.stderr)
            print(f"Run set_default_taxes_pa.py first to create the 0% taxes.", file=sys.stderr)
            cr.rollback()
            sys.exit(1)

        # Odoo 19: tax mapping is on the tax (original_tax_ids = taxes to replace); fp.tax_ids = destination taxes.
        # 4a) Add retencion tax to fiscal position's tax_ids (destination taxes for this FP)
        if retencion_tax not in fp.tax_ids:
            fp.tax_ids = [(4, retencion_tax.id)]
            print(f"Added tax '{TAX_NAME}' to fiscal position '{FP_NAME}' for company {company.name}.")
        # 4b) On the destination tax, set original_tax_ids so 0%% Venta is replaced by Retención when FP is applied
        if tax_0_sale not in retencion_tax.original_tax_ids:
            retencion_tax.original_tax_ids = [(4, tax_0_sale.id)]
            print(f"Fiscal position '{FP_NAME}': map 0%% Venta -> '{TAX_NAME}' for company {company.name}.")

        # 5) Assign fiscal position "Retención de impuestos" to the tax (Posición fiscal field in UI)
        if fp not in retencion_tax.fiscal_position_ids:
            retencion_tax.fiscal_position_ids = [(4, fp.id)]
            print(f"Assigned fiscal position '{FP_NAME}' to tax '{TAX_NAME}' for company {company.name}.")

    cr.commit()
    print("Done. Tax 'Retención de Impuestos' (group 7%) and fiscal position mapping are set.")
    
    # Verify what was created
    for company in companies:
        fiscal_country = company.account_fiscal_country_id or company.country_id
        if fiscal_country and fiscal_country.code != COUNTRY_CODE:
            continue
        retencion_tax = Tax.search([
            ("company_id", "=", company.id),
            ("name", "=", TAX_NAME),
            ("type_tax_use", "=", "sale"),
        ], limit=1)
        if retencion_tax:
            print(f"✓ Verified: Tax '{TAX_NAME}' exists for company {company.name}.")
        else:
            print(f"⚠ WARNING: Tax '{TAX_NAME}' not found for company {company.name} after creation.", file=sys.stderr)
