#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <vm-name>"
  exit 1
fi

VM_NAME="$1"

echo "[INFO] Locating resource group for VM: $VM_NAME..."
RESOURCE_GROUP=$(az vm list --query "[?name=='$VM_NAME'].resourceGroup" -o tsv)

if [[ -z "$RESOURCE_GROUP" ]]; then
  echo "[ERROR] VM '$VM_NAME' not found in your subscription."
  exit 1
fi

echo "[INFO] VM found in resource group: $RESOURCE_GROUP"

echo "[INFO] Fetching network interface for VM..."
NIC_ID=$(az vm show \
  --name "$VM_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "networkProfile.networkInterfaces[0].id" -o tsv)

NIC_NAME=$(basename "$NIC_ID")
NIC_RG=$(echo "$NIC_ID" | cut -d'/' -f5)

echo "[INFO] Getting NSG from NIC..."
NIC_NSG_ID=$(az network nic show \
  --name "$NIC_NAME" \
  --resource-group "$NIC_RG" \
  --query "networkSecurityGroup.id" -o tsv || echo "")

SUBNET_ID=$(az network nic show \
  --name "$NIC_NAME" \
  --resource-group "$NIC_RG" \
  --query "ipConfigurations[0].subnet.id" -o tsv)

SUBNET_RG=$(echo "$SUBNET_ID" | cut -d'/' -f5)
VNET_NAME=$(echo "$SUBNET_ID" | cut -d'/' -f9)
SUBNET_NAME=$(basename "$SUBNET_ID")

echo "[INFO] Getting NSG from subnet (if not attached to NIC)..."
SUBNET_NSG_ID=$(az network vnet subnet show \
  --resource-group "$SUBNET_RG" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_NAME" \
  --query "networkSecurityGroup.id" -o tsv || echo "")

NSG_ID="${NIC_NSG_ID:-$SUBNET_NSG_ID}"

if [[ -z "$NSG_ID" ]]; then
  echo "[ERROR] No NSG associated with NIC or subnet."
  exit 1
fi

NSG_NAME=$(basename "$NSG_ID")
NSG_RG=$(echo "$NSG_ID" | cut -d'/' -f5)

echo "[INFO] Checking NSG: $NSG_NAME for inbound SSH (TCP/22) rules..."

RULES=$(az network nsg rule list \
  --nsg-name "$NSG_NAME" \
  --resource-group "$NSG_RG" \
  --query "[?destinationPortRange=='22' && access=='Allow' && direction=='Inbound']" -o json)

if [[ "$RULES" == "[]" ]]; then
  echo "[WARNING] SSH (TCP/22) is not allowed in NSG: $NSG_NAME"
  exit 2
else
  echo "[SUCCESS] SSH (TCP/22) is allowed via NSG: $NSG_NAME"
fi
