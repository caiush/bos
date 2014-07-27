#!/bin/bash

# Source this file at the top of your script when needing vmrun
# e.g.,
# source ./virtualbox_env.sh

if [[ -z "$VMRUN" ]]; then
  if command -v vmrun >& /dev/null; then
    VMRUN=vmrun
  else
    for i in "/Applications/VMware Fusion.app/Contents/Library/vmrun"; do
      if [[ -x $i ]]; then
        VMRUN="$i"
        break
      fi
    done
  fi

fi

if [[ -z "$VMDISK" ]]; then
  if command -v vmware-vdiskmanager >& /dev/null; then
    VMDISK=vmware-vdiskmanager
  else
    for i in "/Applications/VMware Fusion.app/Contents/Library/vmware-vdiskmanager"; do
      if [[ -x $i ]]; then
        VMDISK="$i"
        break
      fi
    done
  fi

fi
