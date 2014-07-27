#!/bin/bash -e

# bash imports
source ./vmware_env.sh

if [[ -z "$VMRUN" ]]; then
  echo "vmrun not found!" >&2
  echo "  Please ensure VMWare is installed and vmrun is accessible." >&2
  exit 1
fi

if [[ -z "$VMDISK" ]]; then
  echo "vmware-vdiskmanager not found!" >&2
  echo "  Please ensure VMWare is installed and vmware-vdiskmanager is accessible." >&2
  exit 1
fi

if [[ -f ../proxy_setup.sh ]]; then
  . ../proxy_setup.sh
fi
if [[ -z "$CURL" ]]; then
  echo "CURL is not defined"
  exit
fi

# Bootstrap VM Defaults (these need to be exported for Vagrant's Vagrantfile)
export BOOTSTRAP_VM_MEM=1536
export BOOTSTRAP_VM_CPUs=1
# Use this if you intend to make an apt-mirror in this VM (see the
# instructions on using an apt-mirror towards the end of bootstrap.md)
# -- Vagrant VMs do not use this size --
#BOOTSTRAP_VM_DRIVE_SIZE=120480

# Cluster VM Defaults
CLUSTER_VM_MEM=2560
CLUSTER_VM_CPUs=2
CLUSTER_VM_DRIVE_SIZE=20480

VBOX_DIR="`dirname ${BASH_SOURCE[0]}`"
P=`python -c "import os.path; print os.path.abspath(\"${VBOX_DIR}/\")"`

if ! hash vagrant 2> /dev/null ; then
  echo "This script requires Vagrant to be installed!"
  exit 1
fi

if [[ -z `vagrant plugin list | grep vagrant-vmware-fusion` ]]; then
  echo "This script requires vagrant-vmware-fusion to be installed!"
  echo "Try: "
  echo "$ vagrant plugin install vagrant-vmware-fusion"
  echo "$ vagrant plugin license /path/to/license-file"
  echo "See http://www.vagrantup.com/vmware for more info."
  echo "(The vagrant-vmware-fusion plugin is a commercial product.)"
  exit 1
fi

######################################################
# Function to download files necessary for VM stand-up
# 
function download_VM_files {
  pushd $P

  BOX='precise64_vmware.box'

  if [[ ! -f $BOX ]]; then
     $CURL -L -o $BOX http://files.vagrantup.com/precise64_vmware.box
  fi

  popd
}

###################################################################
# Function to create the VMs via Vagrant
function create_VMs {
  pushd $P

  if [[ ! -f insecure_private_key ]]; then
    # Ensure that the private key has been created by running vagrant
    vagrant status
    cp $HOME/.vagrant.d/insecure_private_key .
  fi

  # You have to run this three times initially for each private network
  vagrant up

  # Create each VM vdisk
  for vm in 1 2 3; do
    VM_PATH=`ls -d .vagrant/machines/bcpc_vm$vm/vmware_fusion/*/`
    VMX_PATH=$VM_PATH/precise64.vmx

    if [ ! -f $VMX_PATH ]; then
      echo "Can't find bcpc-vm$vm in $VM_PATH"
      exit 1
    fi

    # offset for boot drive!
    for disk in 1 2 3 4; do
      VMDK_FILE=bcpc-vm$vm-$disk.vmdk
      VMDK_PATH=$VM_PATH/$VMDK_FILE
      if [ ! -f $VMDK_PATH ]; then
         vagrant halt bcpc_vm$vm
         echo "Creating $VMDK_PATH"
        "$VMDISK" -c -s ${CLUSTER_VM_DRIVE_SIZE}MB -a ide -t 0 $VMDK_PATH
        cp $VMX_PATH $VMX_PATH.orig-$disk
        cat >> $VMX_PATH <<EOF
scsi0:${disk}.present = "TRUE"
scsi0:${disk}.filename = "${VMDK_FILE}"
EOF
      fi
    done

    #vagrant up bcpc_vm$vm

  done

  popd
}

function install_cluster {
  environment=${1-Test-Laptop-VMware}
  ip=${2-10.0.100.3}
  pushd $P
  # N.B. As of Aug 2013, grub-pc gets confused and wants to prompt re: 3-way
  # merge.  Sigh.
  #vagrant ssh -c "sudo ucf -p /etc/default/grub"
  #vagrant ssh -c "sudo ucfr -p grub-pc /etc/default/grub"
  vagrant ssh -c "test -f /etc/default/grub.ucf-dist && sudo mv /etc/default/grub.ucf-dist /etc/default/grub" || true
  # Duplicate what d-i's apt-setup generators/50mirror does when set in preseed
  if [ -n "$http_proxy" ]; then
    if [ -z `vagrant ssh -c "grep Acquire::http::Proxy /etc/apt/apt.conf"` ]; then
      vagrant ssh -c "echo 'Acquire::http::Proxy \"$http_proxy\";' | sudo tee -a /etc/apt/apt.conf"
    fi
  fi
  vagrant ssh -c "sudo apt-get install rsync ed apparmor" || true
  popd
  echo "Bootstrap complete - setting up Chef server"
  echo "N.B. This may take approximately 30-45 minutes to complete."
  pushd ../
  ./bootstrap_chef.sh --vagrant-vmware $ip $environment
  popd
  ./vmware_cobbler.sh
}

# only execute functions if being run and not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  download_VM_files
  create_VMs
  install_cluster $*
fi
