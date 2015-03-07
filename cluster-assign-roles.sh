#!/bin/bash
# Script to assign roles to cluster nodes based on a definition in cluster.txt :
#
# - If no hostname is provided, all nodes will be attempted
#
# - if a nodename is provided, either by hostname or ip address, only
#   that node will be attempted
#
# - if the special nodename "heads" is given, all head nodes will be
#   attempted
#
# - if the special nodename "workers" is given, all work nodes will be
#   attempted
#
# - A node may be excluded by setting its role to something other than
#   "head" or "work" in cluster.txt. For example "done" might be
#   useful for nodes that have been completed

set -e
if [[ -z "$1" ]]; then
    echo "Usage : $0 environment (hostname)"
    exit 1
fi

ENVIRONMENT=$1
EXACTHOST=$2

if [[ ! -f "environments/$ENVIRONMENT.json" ]]; then
    echo "Error: Couldn't find '$ENVIRONMENT.json'. Did you forget to pass the environment as first param?"
    exit 1
fi

declare -A FQDNS

while read HOST MACADDR IPADDR ILOIPADDR DOMAIN ROLE; do
    if [[ -z "$EXACTHOST" || "$EXACTHOST" = all || "$EXACTHOST" = "$HOST" || "$EXACTHOST" = "$IPADDR" || "$EXACTHOST" = "heads" && "$ROLE" = "head" || "$EXACTHOST" = "workers" && "$ROLE" = "work" ]]; then
        IDX=`echo $IPADDR | tr '.' '-'`
        if [[ "$ROLE" = "bootstrap" ]]; then
            continue
        fi
        if   [[ "$ROLE" = head ]]; then
            HEADS="$HEADS $IPADDR"
            FQDNS["$IDX"]="${HOST}.${DOMAIN}"
        elif [[ "$ROLE" = work ]]; then
            WORKERS="$WORKERS $IPADDR"
            FQDNS["$IDX"]="${HOST}.${DOMAIN}"
        elif [[ "$ROLE" = mon ]]; then
            MONS="$MONS $IPADDR"
            FQDNS["$IDX"]="${HOST}.${DOMAIN}"
        elif [[ "$ROLE" = osd ]]; then
            OSDS="$OSDS $IPADDR"
            FQDNS["$IDX"]="${HOST}.${DOMAIN}"
        fi  
    fi
done < cluster.txt
echo "heads : $HEADS"
echo "workers : $WORKERS"
echo "mons : $MONS"
echo "osds : $OSDS"

PASSWD=`knife data bag show configs $ENVIRONMENT | grep "cobbler-root-password:" | awk ' {print $2}'`

# Head nodes use an unbundled initialisation - chef is installed from
# a .deb (allowing disconnected working) and then the node is
# bootstrapped with no role to start, and then it is made admin, and
# then the role is assigned, finally chef-client is run
for HEAD in $HEADS; do
    MATCH=$HEAD
    echo "About to bootstrap head node $HEAD..."
    ./chefit.sh $HEAD $ENVIRONMENT
    echo $PASSWD | sudo knife bootstrap -E $ENVIRONMENT $HEAD -x ubuntu  -P $PASSWD --sudo
    IDX=`echo $HEAD | tr '.' '-'`
    FQDN=${FQDNS["$IDX"]}
    ./make-admin.sh $FQDN
    knife node run_list add $FQDN 'role[BCPC-Headnode]'
    SSHCMD="./nodessh.sh $ENVIRONMENT $HEAD"
    $SSHCMD "/home/ubuntu/finish-head.sh" sudo  
done

for MON in $MONS; do
    MATCH=$MON
    echo "About to bootstrap head node $MON..."
    ./chefit.sh $MON $ENVIRONMENT
    echo $PASSWD | sudo knife bootstrap -E $ENVIRONMENT $MON -x ubuntu  -P $PASSWD --sudo
    IDX=`echo $MON | tr '.' '-'`
    FQDN=${FQDNS["$IDX"]}
    ./make-admin.sh $FQDN
    knife node run_list add $FQDN 'role[BCPC-StorageMon]'
    SSHCMD="./nodessh.sh $ENVIRONMENT $MON"
    $SSHCMD "/home/ubuntu/finish-head.sh" sudo  
done
# Work nodes are simpler than head nodes. After installation of Chef
# we can let knife bootstrap do the rest.
for WORKER in $WORKERS; do
    MATCH=$WORKER
    echo "About to bootstrap worker worker $WORKER..."
    ./chefit.sh $WORKER $ENVIRONMENT
    echo $PASSWD | sudo knife bootstrap -E $ENVIRONMENT -r 'role[BCPC-Worknode]' $WORKER -x ubuntu -P $PASSWD --sudo
    SSHCMD="./nodessh.sh $ENVIRONMENT $WORKER"
    $SSHCMD "/home/ubuntu/finish-worker.sh" sudo    
done
for OSD in $OSDS; do
    MATCH=$OSD
    echo "About to bootstrap worker worker $OSD..."
    ./chefit.sh $OSD $ENVIRONMENT
    echo $PASSWD | sudo knife bootstrap -E $ENVIRONMENT -r 'role[BCPC-Storage]' $OSD -x ubuntu -P $PASSWD --sudo
    SSHCMD="./nodessh.sh $ENVIRONMENT $OSD"
    $SSHCMD "/home/ubuntu/finish-worker.sh" sudo    
done



if [[ -z "$MATCH" ]]; then
    echo "Warning: No nodes found"
fi

