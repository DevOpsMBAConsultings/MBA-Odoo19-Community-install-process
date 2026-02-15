#!/usr/bin/env python3
"""
Set Kanban as the default view for Contacts (res.partner) actions.

Sets the sequence on view_ids so Kanban has sequence=1 (lowest) and List (tree) has sequence=10.
Also ensures view_mode starts with 'kanban' as backup.

UI equivalent: Ajustes > Técnico > Interfaz de usuario > Acciones de ventana > search
Contacts (res.partner), go to "Vistas" tab, set Kanban sequence=1, List sequence=10.

Run after base/contacts are installed. Uses ODOO_CONF, DB_NAME, ODOO_HOME.
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

    if "ir.actions.act_window" not in env:
        print("WARNING: ir.actions.act_window not found. Skipping.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    actions = env["ir.actions.act_window"].search([("res_model", "=", "res.partner")])
    updated_actions = 0
    updated_views = 0
    
    for action in actions:
        # Method 1: Set sequence on view_ids (this is what actually controls default view)
        if hasattr(action, "view_ids") and action.view_ids:
            kanban_view = action.view_ids.filtered(lambda v: v.view_mode == "kanban")
            tree_view = action.view_ids.filtered(lambda v: v.view_mode == "tree")
            
            if kanban_view:
                for kv in kanban_view:
                    if kv.sequence != 1:
                        kv.sequence = 1
                        updated_views += 1
                        print(f"Set Kanban view sequence=1 for action '{action.name}' (id={action.id}).")
            
            if tree_view:
                for tv in tree_view:
                    if tv.sequence < 10:
                        tv.sequence = 10
                        updated_views += 1
                        print(f"Set List (tree) view sequence=10 for action '{action.name}' (id={action.id}).")
        
        # Method 2: Also ensure view_mode starts with kanban (backup/fallback)
        view_mode = (action.view_mode or "").strip()
        if view_mode:
            modes = [m.strip() for m in view_mode.split(",") if m.strip()]
            if modes and modes[0] != "kanban":
                # Put kanban first; keep other modes in order (add kanban if missing)
                rest = [m for m in modes if m != "kanban"]
                new_modes = ["kanban"] + rest
                action.write({"view_mode": ",".join(new_modes)})
                updated_actions += 1
                print(f"Set view_mode to start with Kanban for action '{action.name}' (id={action.id}).")

    cr.commit()
    if updated_views > 0:
        print(f"Done. Updated {updated_views} view sequence(s) and {updated_actions} view_mode(s) to default to Kanban.")
    else:
        print(f"Done. Updated {updated_actions} view_mode(s) to default to Kanban (view_ids sequences already correct or not available).")
