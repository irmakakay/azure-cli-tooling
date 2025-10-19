#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <vm-name>"
  exit 1
fi

VM_NAME="$1"

echo "[*] Getting subscription ID..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

if [ -z "$SUBSCRIPTION_ID" ]; then
  echo "[!] Unable to get subscription ID. Are you logged in?"
  exit 1
fi

echo "[*] Searching DevTest Labs..."

LABS=$(az resource list --resource-type "Microsoft.DevTestLab/labs" \
  --query "[].{lab: name, rg: resourceGroup}" -o tsv)

if [ -z "$LABS" ]; then
  echo "[!] No DevTest Labs found."
  exit 1
fi

FOUND=0

while read -r LAB_NAME RG_NAME; do
  echo "[*] Checking lab: $LAB_NAME in RG: $RG_NAME"

  # List VMs in this lab
  VMS=$(az resource list \
    --resource-group "$RG_NAME" \
    --query "[?type=='Microsoft.DevTestLab/labs/virtualMachines'].[name]" \
    -o tsv)

  for FULL_NAME in $VMS; do
    SHORT_VM_NAME=$(echo "$FULL_NAME" | cut -d'/' -f2)

    if [ "$SHORT_VM_NAME" == "$VM_NAME" ]; then
      echo "[+] Found VM '$VM_NAME' in lab '$LAB_NAME' (RG: $RG_NAME)"
      
      URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.DevTestLab/labs/$LAB_NAME/virtualmachines/$VM_NAME/start?api-version=2018-09-15"

      echo "[*] Sending start request via az rest..."
      az rest --method post --uri "$URI"

      echo "[✓] Start request sent."
      FOUND=1
      break 2
    fi
  done
done <<< "$LABS"

if [ "$FOUND" -eq 0 ]; then
  echo "[!] VM '$VM_NAME' not found in any DevTest Lab."
  exit 1
fi
