#!/usr/bin/env python3
"""
Create tax "Retención de Impuestos" as a tax group (Grupo de impuestos) with:
1. "ITBMS 7% (Operaciones con Retención)" (7%)
2. "ITBMS 50% (Operaciones con Retención)" (-3.5%)

And assign it to the fiscal position "Retención de impuestos".

Run after set_fiscal_position_retencion.py and set_default_taxes_pa.py.
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
TAX_GROUP_NAME = (os.environ.get("ODOO_TAX_GROUP_RETENCION_NAME") or "Retención de Impuestos").strip()
TAX_FINAL_NAME = "Retención de impuestos" # The group tax name

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
        
        print(f"--- Processing Company: {company.name} ---")

        # ---------------------------------------------------------------------
        # Paso 3 (Pre-req): Creación de grupo de impuestos (Tax Group)
        # ---------------------------------------------------------------------
        # Name: Retención de Impuestos
        group = TaxGroup.search(
            [
                ("company_id", "=", company.id),
                ("country_id", "=", country.id),
                ("name", "=", TAX_GROUP_NAME),
            ],
            limit=1,
        )
        if not group:
            group = TaxGroup.create(
                {
                    "name": TAX_GROUP_NAME,
                    "company_id": company.id,
                    "country_id": country.id,
                }
            )
            print(f"  [CREATE] Tax Group '{TAX_GROUP_NAME}'")
        else:
             print(f"  [EXISTS] Tax Group '{TAX_GROUP_NAME}'")

        # ---------------------------------------------------------------------
        # Paso 1. Creación de Impuesto de 7%
        # Nombre del Impuesto: ITBMS 7% (Operaciones con Retención)
        # ---------------------------------------------------------------------
        tax1_name = "ITBMS 7% (Operaciones con Retención)"
        tax1 = Tax.search(
            [
                ("company_id", "=", company.id),
                ("type_tax_use", "=", "sale"),
                ("name", "=", tax1_name),
            ],
            limit=1,
        )
        
        tax1_vals = {
            "name": tax1_name,
            "type_tax_use": "sale",
            "amount_type": "percent",
            "amount": 7.0,
            "description": "ITBMS 7% Venta",
            "tax_group_id": group.id,
            "country_id": country.id,
            "company_id": company.id,
            # Config options
            "price_include": False,
            "include_base_amount": False,      # Afecta la base de los impuestos subscuentes: <En Blanco> (False)
            "is_base_affected": True,          # Base afectada por impuestos previos: Checked (True)
            # Label (Etiqueta on invoices)
            "invoice_label": "7%", 
        }

        if not tax1:
            tax1 = Tax.create(tax1_vals)
            print(f"  [CREATE] Tax 1: '{tax1_name}'")
        else:
            tax1.write(tax1_vals)
            print(f"  [UPDATE] Tax 1: '{tax1_name}'")


        # ---------------------------------------------------------------------
        # Paso 2. Creación de Impuesto de Retención de 50%
        # Nombre del Impuesto: ITBMS 50% (Operaciones con Retención)
        # Importe: -3.5%
        # ---------------------------------------------------------------------
        tax2_name = "ITBMS 50% (Operaciones con Retención)"
        tax2 = Tax.search(
            [
                ("company_id", "=", company.id),
                ("type_tax_use", "=", "sale"),
                ("name", "=", tax2_name),
            ],
            limit=1,
        )
        
        tax2_vals = {
            "name": tax2_name,
            "type_tax_use": "sale",
            "amount_type": "percent",
            "amount": -3.5,
            "description": "ITBMS -50% Venta",
            "tax_group_id": group.id,
            "country_id": country.id,
            "company_id": company.id,
            # Config options
            "price_include": False,
            "include_base_amount": False,      # Afecta la base de los impuestos subscuentes: <En Blanco> (False)
            "is_base_affected": False,         # Base afectada por impuestos previos: <En Blanco> (False)
            # Label
            "invoice_label": "-3.5%",
        }

        if not tax2:
            tax2 = Tax.create(tax2_vals)
            print(f"  [CREATE] Tax 2: '{tax2_name}'")
        else:
            tax2.write(tax2_vals)
            print(f"  [UPDATE] Tax 2: '{tax2_name}'")

        # ---------------------------------------------------------------------
        # Paso 3. Creación de grupo de impuestos (The Tax Object)
        # Nombre del Impuesto: Retención de impuestos
        # Cálculo de Impuestos: Grupo de Impuestos
        # ---------------------------------------------------------------------
        
        final_tax = Tax.search(
            [
                ("company_id", "=", company.id),
                ("country_id", "=", country.id),
                ("name", "=", TAX_FINAL_NAME),
                ("type_tax_use", "=", "sale"),
            ],
            limit=1,
        )

        final_tax_vals = {
            "name": TAX_FINAL_NAME,
            "type_tax_use": "sale",
            "amount_type": "group",
            "company_id": company.id,
            "country_id": country.id,
            "tax_group_id": group.id,
            "children_tax_ids": [(6, 0, [tax1.id, tax2.id])],
            "description": False, # Description blank per requirements
            "invoice_label": False, # Etiqueta blank
        }

        if not final_tax:
            final_tax = Tax.create(final_tax_vals)
            print(f"  [CREATE] Group Tax Object: '{TAX_FINAL_NAME}' containing [7%, -3.5%]")
        else:
            final_tax.write(final_tax_vals)
            print(f"  [UPDATE] Group Tax Object: '{TAX_FINAL_NAME}'")


        # ---------------------------------------------------------------------
        # 4) Fiscal position "Retención de impuestos"
        # ---------------------------------------------------------------------
        fp = FiscalPosition.search(
            [
                ("company_id", "=", company.id),
                ("name", "=", FP_NAME),
            ],
            limit=1,
        )
        if not fp:
            print(f"  [ERROR] Fiscal position '{FP_NAME}' not found. Run set_fiscal_position_retencion.py first.", file=sys.stderr)
            # Check if we should create it or fail? 
            # The previous script assumes it exists. We will try to create it if missing as a fallback
            fp = FiscalPosition.create({
                "name": FP_NAME,
                "company_id": company.id,
                "country_id": country.id,
                "auto_apply": False,
            })
            print(f"  [CREATE] Fiscal position '{FP_NAME}' (fallback created)")

        # Source: Exento 0% Venta
        # Note: Previous script looked for "Exento 0% Venta". 
        # We need to find the 0% tax to map FROM.
        # Ideally we search for a tax with amount 0 and type sale.
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
            # Fallback search by name if multiple 0% exist or none found by amount
            tax_0_sale = Tax.search([
                ("company_id", "=", company.id),
                ("type_tax_use", "=", "sale"),
                ("name", "ilike", "Exento"),
            ], limit=1)

        if not tax_0_sale:
            print(f"  [ERROR] source 0% sale tax not found. Cannot set mapping.", file=sys.stderr)
        else:
            # Add mapping: 0% -> Retención de impuestos (The group tax)
            
            # Check if mapping exists
            # Odoo 19/18 model for fiscal position tax lines: account.fiscal.position.tax
            # Fields: position_id, src_tax_id, tax_dest_id
            
            # First, check if the mapping already exists
            existing_mapping = env["account.fiscal.position.tax"].search([
                ("position_id", "=", fp.id),
                ("src_tax_id", "=", tax_0_sale.id),
                ("tax_dest_id", "=", final_tax.id),
            ], limit=1)
            
            if not existing_mapping:
                # Remove any other mapping for this source tax to avoid conflicts (optional but safer)
                old_mappings = env["account.fiscal.position.tax"].search([
                    ("position_id", "=", fp.id),
                    ("src_tax_id", "=", tax_0_sale.id),
                ])
                if old_mappings:
                    old_mappings.unlink()
                    print(f"  [Unlinked] Old mappings for source tax {tax_0_sale.name}")
                
                env["account.fiscal.position.tax"].create({
                    "position_id": fp.id,
                    "src_tax_id": tax_0_sale.id,
                    "tax_dest_id": final_tax.id,
                })
                print(f"  [MAPPING] {tax_0_sale.name} -> {final_tax.name} in '{fp.name}'")
            else:
                print(f"  [MAPPING] Already exists: {tax_0_sale.name} -> {final_tax.name}")

    cr.commit()
    print("Done.")
