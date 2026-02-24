#!/bin/bash
set -e

ODOO_USER="odoo"
TARGET_DIR="/opt/odoo/custom-addons"
ODOO_VERSION="${ODOO_VERSION:-19.0}" # Service name suffix (e.g. odoo19)
# If ODOO_VERSION is just "19", we might need "19.0" for the branch.
if [[ "$ODOO_VERSION" =~ ^[0-9]+$ ]]; then
  TARGET_BRANCH="${ODOO_VERSION}.0"
else
  TARGET_BRANCH="$ODOO_VERSION"
fi
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADDONS_FILE="$REPO_ROOT/custom_addons.txt"

echo "Installing custom addons from Git repositories..."

# Ensure git is installed
if ! command -v git >/dev/null 2>&1; then
  echo "🔧 git not found — installing..."
  apt-get update -y
  apt-get install -y git
fi

mkdir -p "$TARGET_DIR"

if [ ! -f "$ADDONS_FILE" ]; then
  echo "⚠️ Addon list not found: $ADDONS_FILE"
  echo "Skipping custom addon installation."
  exit 0
fi


  
  while IFS= read -r repo_url || [ -n "$repo_url" ]; do
    # Skip comments and empty lines
    repo_url=$(echo "$repo_url" | xargs) # Trim whitespace
    [[ "$repo_url" =~ ^#.*$ ]] && continue
    [[ -z "$repo_url" ]] && continue
  
  
    repo_name=$(basename "$repo_url" .git)
    clone_path="$TARGET_DIR/$repo_name"
    
    echo "➡️ Processing repository: ${repo_name}"
    
    if [ -d "$clone_path" ]; then
        echo "Directory ${clone_path} already exists. Skipping clone."
        continue
    fi
  
    # Attempt to clone the specific Odoo version branch, fall back to default branch
    if ! git clone --depth 1 --branch "$TARGET_BRANCH" "$repo_url" "$clone_path" 2>/dev/null; then
      echo "    Branch '$TARGET_BRANCH' not found. Trying default branch..."
      git clone --depth 1 "$repo_url" "$clone_path" || echo "❌ Failed to clone $repo_name. Skipping."
    fi
  
  done < "$ADDONS_FILE"
  
  # -------------------------------------------------------------------
  # Auto-discovery & Dependency Management
  # -------------------------------------------------------------------
  
  AUTO_ADDONS_DIR="/opt/odoo/auto-addons"
  echo "🔍 scanning for modules and dependencies..."
  
  # Create auto-addons directory for symlinks
  mkdir -p "$AUTO_ADDONS_DIR"
  # Clean up old symlinks to ensure fresh state
  rm -rf "${AUTO_ADDONS_DIR:?}"/*
  
  # Activate venv for pip install
  if [ -f "/opt/odoo/odoo${ODOO_VERSION}/venv/bin/activate" ]; then
      source "/opt/odoo/odoo${ODOO_VERSION}/venv/bin/activate"
  fi
  
  # Function to process a directory (recursively look for modules)
  process_repo() {
      local repo_dir="$1"
      local found_module=0
  
      # install requirements.txt if present at repo root
      if [ -f "$repo_dir/requirements.txt" ]; then
          echo "📦 Installing python dependencies for $(basename "$repo_dir")..."
          pip install -r "$repo_dir/requirements.txt" || echo "⚠️ Warning: Failed to install requirements for $(basename "$repo_dir")"
      fi
  
      # Check if the repo root itself is a module
      if [ -f "$repo_dir/__manifest__.py" ]; then
          ln -s "$repo_dir" "$AUTO_ADDONS_DIR/$(basename "$repo_dir")"
          found_module=1
      else
          # Look for sub-directories that are modules
          for sub in "$repo_dir"/*; do
              if [ -d "$sub" ] && [ -f "$sub/__manifest__.py" ]; then
                  local mod_name=$(basename "$sub")
                  echo "    Found module: $mod_name"
                  ln -s "$sub" "$AUTO_ADDONS_DIR/$mod_name"
                  
                  # Check for inner requirements.txt
                  if [ -f "$sub/requirements.txt" ]; then
                       echo "📦 Installing python dependencies for module $mod_name..."
                       pip install -r "$sub/requirements.txt" || echo "⚠️ Warning: Failed to install requirements for $mod_name"
                  fi
                  found_module=1
              fi
          done
      fi
  
      if [ "$found_module" -eq 0 ]; then
          echo "⚠️  No modules found in $(basename "$repo_dir") (checked root and first level)."
      fi
  }
  
  # Iterate over all cloned repositories in custom-addons
  if [ -d "$TARGET_DIR" ]; then
      for repo in "$TARGET_DIR"/*; do
          if [ -d "$repo" ]; then
              process_repo "$repo"
          fi
      done
  fi
  
  echo "🔐 Setting permissions..."
  chown -R "$ODOO_USER:$ODOO_USER" "$TARGET_DIR"
  chown -R "$ODOO_USER:$ODOO_USER" "$AUTO_ADDONS_DIR"
  
  echo "🔄 Restarting Odoo to apply changes..."
  if systemctl is-active --quiet "odoo${ODOO_VERSION}"; then
    systemctl restart "odoo${ODOO_VERSION}"
    echo "✅ Odoo service restarted."
  else
    echo "⚠️ Odoo service not found or not active. Attempting start..."
    # Try to start it
    systemctl start "odoo${ODOO_VERSION}" || true
    sleep 2
    if systemctl is-active --quiet "odoo${ODOO_VERSION}"; then
       echo "✅ Odoo service started successfully."
    else
       echo "❌ Failed to restart/start Odoo service. Check logs:"
       systemctl status "odoo${ODOO_VERSION}" --no-pager | tail -n 10 || true
    fi
  fi

echo "✅ Custom addons installation script finished."
