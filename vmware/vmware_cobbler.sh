#!/bin/bash

set -e

DIR=`dirname $0`

pushd $DIR

subnet=10.0.100
node=11
for i in `seq 1 3`; do
  VM_PATH=`ls -d .vagrant/machines/bcpc_vm${i}/vmware_fusion/*/`
  VMX_PATH=$VM_PATH/precise64.vmx
  vm_name=bcpc-vm${i}
  MAC=`grep -i "ethernet1.generatedAddress =" ${VMX_PATH} | cut -d \" -f 2`
  if [ -z "$MAC" ]; then 
    echo "***ERROR: Unable to get MAC address for ${vm_name} (${VMX_PATH})"
    exit 1 
  fi 
  echo "Registering ${vm_name} with $MAC for ${subnet}.${node}"
  vagrant ssh -c "sudo cobbler system remove --name=${vm_name}; sudo cobbler system add --name=${vm_name} --hostname=${vm_name} --profile=bcpc_host --ip-address=${subnet}.${node} --mac=${MAC}"
  let node=node+1
done

vagrant ssh -c "sudo cobbler sync"
