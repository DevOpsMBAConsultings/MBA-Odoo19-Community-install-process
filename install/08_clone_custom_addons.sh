#!/bin/bash
set -e

ODOO_USER="odoo"
TARGET_DIR="/opt/odoo/custom-addons"
ODOO_VERSION="19.0" # Target branch for addons
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

# Determine GitHub token if a private repo is listed
if grep -v '^[[:space:]]*#' "$ADDONS_FILE" | grep -q "your-github-token" && [ -z "${GITHUB_TOKEN:-}" ]; then
  KEY_FILE="$REPO_ROOT/config/token.txt"
  if [ -f "$KEY_FILE" ]; then
    # Read token from key file, ignoring comments and taking the last valid line
    TOKEN_FROM_FILE=$(grep -v '^#' "$KEY_FILE" | awk 'NF' | tail -n 1)
    if [ -n "$TOKEN_FROM_FILE" ] && [ "$TOKEN_FROM_FILE" != "your-token-goes-here" ]; then
      echo "🔑 Token found in $KEY_FILE. Using it for private repositories."
      GITHUB_TOKEN="$TOKEN_FROM_FILE"
    fi
  fi

  # If token is still not set, fall back to interactive prompt
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "⚠️ 'your-github-token' placeholder detected but no token found in config/token.txt."
    echo "   Repositories using the placeholder will be skipped."
    echo "   (If you embedded the token in the URL directly, this warning can be ignored.)"
  fi
fi


while IFS= read -r repo_url || [ -n "$repo_url" ]; do
  # Skip comments and empty lines
  repo_url=$(echo "$repo_url" | xargs) # Trim whitespace
  [[ "$repo_url" =~ ^#.*$ ]] && continue
  [[ -z "$repo_url" ]] && continue

  # Handle private repos that require a token
  if [[ "$repo_url" == *your-github-token* ]]; then
    if [ -n "${GITHUB_TOKEN:-}" ]; then
      repo_url="${repo_url/your-github-token/$GITHUB_TOKEN}"
    else
      echo "🚫 Skipping private repo as no GitHub token was provided: $repo_url"
      continue
    fi
  fi

  repo_name=$(basename "$repo_url" .git)
  clone_path="$TARGET_DIR/$repo_name"
  
  echo "➡️ Processing repository: ${repo_name}"
  
  if [ -d "$clone_path" ]; then
      echo "Directory ${clone_path} already exists. Skipping clone."
      continue
  fi

  # Attempt to clone the specific Odoo version branch, fall back to default branch
  if ! git clone --depth 1 --branch "$ODOO_VERSION" "$repo_url" "$clone_path" 2>/dev/null; then
    echo "    Branch '$ODOO_VERSION' not found. Trying default branch..."
    git clone --depth 1 "$repo_url" "$clone_path" || echo "❌ Failed to clone $repo_name. Skipping."
  fi

done < "$ADDONS_FILE"

echo "🔐 Setting permissions for all addons..."
chown -R "$ODOO_USER:$ODOO_USER" "$TARGET_DIR"
chmod -R 755 "$TARGET_DIR"

echo "🔄 Restarting Odoo to apply changes..."
if systemctl is-active --quiet odoo19; then
  systemctl restart odoo19
  echo "✅ Odoo service restarted."
else
  echo "⚠️ Odoo service not found or not active. Please start/restart it manually."
fi

echo "✅ Custom addons installation script finished."
