#!/bin/bash

# bash imports
source ./vmware_env.sh

for i in `seq 1 3`; do
  VM_PATH=`ls -d .vagrant/machines/bcpc_vm${i}/vmware_fusion/*/`
  VMX_PATH=$VM_PATH/precise64.vmx
  if [ ! -f $VMX_PATH ]; then
    echo "Unable to find VM $i - $VMX_PATH! Exiting."
    exit 1
  fi
  "$VMRUN" snapshot $VMX_PATH initial-install
done
