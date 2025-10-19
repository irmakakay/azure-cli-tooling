#!/bin/bash
set -euo pipefail

SOURCE_SERVER="pgsqlflexible-cmre"
SOURCE_RG="rg_cmre_infra"
TARGET_SERVER="pgsqlflexible-shape"
LOCATION="uksouth"
ADMIN_USER="loccmreadm"

log() {
  echo "[INFO] $1"
}

error() {
  echo "[ERROR] $1" >&2
  exit 1
}

log "Fetching source server configuration..."
SOURCE_INFO=$(az postgres flexible-server show \
  --name "$SOURCE_SERVER" \
  --resource-group "$SOURCE_RG" \
  -o json)

if [[ -z "$SOURCE_INFO" ]]; then
  error "Unable to fetch source server details."
fi

VERSION=$(echo "$SOURCE_INFO" | jq -r '.version')
SKU_NAME=$(echo "$SOURCE_INFO" | jq -r '.sku.name')
SKU_TIER=$(echo "$SOURCE_INFO" | jq -r '.sku.tier')
STORAGE_SIZE=$(echo "$SOURCE_INFO" | jq -r '.storage.storageSizeGb // empty')
BACKUP_RETENTION=$(echo "$SOURCE_INFO" | jq -r '.backupRetentionDays // empty')

if [[ -z "$STORAGE_SIZE" ]]; then
  STORAGE_SIZE=128
  log "Storage size not found, using default: $STORAGE_SIZE GB"
fi

if [[ -z "$BACKUP_RETENTION" ]]; then
  BACKUP_RETENTION=7
  log "Backup retention not found, using default: $BACKUP_RETENTION days"
fi

log "Source configuration:"
echo "  Version          : $VERSION"
echo "  SKU              : $SKU_NAME ($SKU_TIER)"
echo "  Storage (GB)     : $STORAGE_SIZE"
echo "  Backup Retention : $BACKUP_RETENTION days"

# Step 2: Prompt for password
read -s -p "Enter password for admin user '$ADMIN_USER': " ADMIN_PASS
echo

# Step 3: Create target server
log "Creating new server: $TARGET_SERVER..."
az postgres flexible-server create \
  --name "$TARGET_SERVER" \
  --resource-group "$SOURCE_RG" \
  --location "$LOCATION" \
  --version "$VERSION" \
  --sku-name "$SKU_NAME" \
  --tier "$SKU_TIER" \
  --storage-size "$STORAGE_SIZE" \
  --backup-retention "$BACKUP_RETENTION" \
  --admin-user "$ADMIN_USER" \
  --admin-password "$ADMIN_PASS" \
  --public-access none \
  --yes

log "Clone complete: $TARGET_SERVER created in $SOURCE_RG"
