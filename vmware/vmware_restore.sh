#!/bin/bash

# bash imports
source ./vmware_env.sh

if [[ -z "$VMRUN" ]]; then
  echo "vmrun not found!" >&2
  echo "  Please ensure VMWare is installed and vmrun is accessible." >&2
  exit 1
fi

for i in `seq 1 3`; do
  VM_PATH=`ls -d .vagrant/machines/bcpc_vm${i}/vmware_fusion/*/`
  VMX_PATH=$VM_PATH/precise64.vmx
  if [ ! -f $VMX_PATH ]; then
    echo "Unable to find VM $i - $VMX_PATH! Exiting."
    exit 1
  fi

  echo "Restoring bcpc-vm${i} from snapshot"
  "$VMRUN" stop $VMX_PATH
  "$VMRUN" revertToSnapshot $VMX_PATH initial-install
  vagrant ssh -c "cd chef-bcpc && knife client delete -y bcpc-vm$i.local.lan" || true
  vagrant ssh -c "cd chef-bcpc && knife node delete -y bcpc-vm$i.local.lan" || true
  "$VMRUN" start $VMX_PATH
done
