#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <vm-name>"
  exit 1
fi

VM_NAME="$1"
CACHE_FILE="$HOME/.devtestlab_cache_${VM_NAME}.json"

function load_cache() {
  if [ -f "$CACHE_FILE" ]; then
    SUBSCRIPTION_ID=$(jq -r .subscription_id "$CACHE_FILE")
    RG_NAME=$(jq -r .resource_group "$CACHE_FILE")
    LAB_NAME=$(jq -r .lab_name "$CACHE_FILE")
    echo "[*] Loaded cache: SUBSCRIPTION_ID=$SUBSCRIPTION_ID, RG=$RG_NAME, LAB=$LAB_NAME"
    return 0
  else
    return 1
  fi
}

function validate_lab() {
  az resource show --resource-group "$RG_NAME" \
    --name "$LAB_NAME" \
    --resource-type "Microsoft.DevTestLab/labs" \
    > /dev/null 2>&1
  return $?
}

# Check for jq
if ! command -v jq > /dev/null; then
  echo "[!] 'jq' is required but not installed. Please install it first."
  exit 1
fi

# Try loading cache
if ! load_cache || ! validate_lab; then
  echo "[*] Cache is missing or invalid. Re-discovering lab..."
  ./cache-lab.sh "$VM_NAME"
  if ! load_cache || ! validate_lab; then
    echo "[!] Failed to retrieve or validate lab info."
    exit 1
  fi
fi

echo "[*] Sending start request..."
URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.DevTestLab/labs/$LAB_NAME/virtualmachines/$VM_NAME/start?api-version=2018-09-15"
az rest --method post --uri "$URI"

echo "[✓] Start request sent for VM '$VM_NAME'"
