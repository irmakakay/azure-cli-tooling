#!/bin/bash

VM_NAME="$1"
RG_NAME="$2" # Optional: pass RG or search all

if [ -z "$VM_NAME" ]; then
  echo "Usage: $0 <vm-name> [resource-group]"
  exit 1
fi

echo "[*] Locating DevTest Labs..."
if [ -z "$RG_NAME" ]; then
  LABS=$(az resource list --resource-type "Microsoft.DevTestLab/labs" \
    --query "[].{lab: name, rg: resourceGroup}" -o tsv)
else
  LABS=$(az resource list --resource-group "$RG_NAME" --resource-type "Microsoft.DevTestLab/labs" \
    --query "[].{lab: name, rg: resourceGroup}" -o tsv)
fi

FOUND=0

while read -r LAB_NAME LAB_RG; do
  echo "[*] Checking lab: $LAB_NAME (RG: $LAB_RG)"

  VMS=$(az resource list \
    --resource-group "$LAB_RG" \
    --query "[?type=='Microsoft.DevTestLab/labs/virtualMachines'].[name]" \
    -o tsv)

  for FULL_NAME in $VMS; do
    SHORT_VM_NAME=$(echo "$FULL_NAME" | cut -d'/' -f2)
    if [[ "$SHORT_VM_NAME" == "$VM_NAME" ]]; then
      echo "[✓] Found VM '$VM_NAME' in lab '$LAB_NAME' (RG: $LAB_RG)"
      
      az resource show \
        --resource-group "$LAB_RG" \
        --name "$LAB_NAME/virtualMachines/$VM_NAME" \
        --resource-type "Microsoft.DevTestLab/labs/virtualMachines" \
        --api-version 2018-09-15 \
        -o json > original-vm.json

      echo "[✓] Saved to original-vm.json"
      FOUND=1
      break 2
    fi
  done
done <<< "$LABS"

if [ "$FOUND" -eq 0 ]; then
  echo "[!] VM '$VM_NAME' not found in any DevTest Lab."
  exit 1
fi
