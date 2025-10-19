#!/bin/bash

set -euo pipefail

# Global configuration
SOURCE_VM="vmcmre-mmapi-prod-01"
RESOURCE_GROUP="rg_dtl_cmre_expl_dynamic"
SNAPSHOT_NAME="${SOURCE_VM}-os-snap"
CLONE_DISK_NAME="${SOURCE_VM}-os-disk-clone"
CLONE_VM_NAME="${SOURCE_VM}-clone"
LOCATION="uksouth"

log_info() {
  echo -e "[INFO] $*"
}

log_error() {
  echo -e "[ERROR] $*" >&2
}

abort_on_failure() {
  log_error "$1"
  exit 1
}

create_snapshot() {
  log_info "Fetching OS disk ID for $SOURCE_VM..."
  OS_DISK_ID=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$SOURCE_VM" \
    --query "storageProfile.osDisk.managedDisk.id" \
    --output tsv) || abort_on_failure "Failed to get OS disk ID."

  log_info "Creating snapshot $SNAPSHOT_NAME from OS disk..."
  az snapshot create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$SNAPSHOT_NAME" \
    --source "$OS_DISK_ID" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --output none || abort_on_failure "Snapshot creation failed."
}

create_managed_disk() {
  log_info "Creating managed disk $CLONE_DISK_NAME from snapshot..."
  az disk create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLONE_DISK_NAME" \
    --source "$SNAPSHOT_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --output none || abort_on_failure "Managed disk creation failed."
}

create_vm_from_disk() {
  log_info "Creating VM $CLONE_VM_NAME from managed disk..."
  
  VM_SIZE=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$SOURCE_VM" \
    --query "hardwareProfile.vmSize" -o tsv) || abort_on_failure "Failed to get VM size."

  SUBNET_ID=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$SOURCE_VM" \
    --query "networkProfile.networkInterfaces[0].id" -o tsv \
    | xargs -I {} az network nic show --ids {} \
    --query "ipConfigurations[0].subnet.id" -o tsv) || abort_on_failure "Failed to get subnet."

  az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLONE_VM_NAME" \
    --attach-os-disk "$CLONE_DISK_NAME" \
    --os-type Linux \
    --size "$VM_SIZE" \
    --subnet "$SUBNET_ID" \
    --location "$LOCATION" \
    --public-ip-address "" \
    --nics "" \
    --generate-ssh-keys \
    --output none || abort_on_failure "VM creation failed."
}

main() {
  log_info "=== Cloning VM: $SOURCE_VM in $RESOURCE_GROUP ==="
  create_snapshot
  create_managed_disk
  create_vm_from_disk
  log_info "=== Clone completed: $CLONE_VM_NAME ==="
}

main "$@"
