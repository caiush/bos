#!/bin/bash
if [[ -n $1 && "$1" = overwrite ]]; then
    OVERW="true"
fi

SSHCOMMON="-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o VerifyHostKeyDNS=no"
SSHCMD="ssh $SSHCOMMON"
SCPCMD="scp $SSHCOMMON"

BOOT=`./cluster-whatsup.sh bcpc-bootstrap | grep 10`
if [[ ${BOOT} = "10.0.100.3" ]]; then
    echo "Bootstrap node is up..."
    if [[ ! -d ../output ]]; then
        mkdir ../output
    else
        echo "Output directory ../output exists."
        if [[ -f ../output/bins.tar.gz || -f ../output/cookbooks.tar.gz ]]; then
            if [[ -z "$OVERW" ]]; then
                echo "output files already exist, not overwiting..."
                exit 1
            else
                echo "overwriting specified, continuing."
            fi
        fi
    fi
    BNDO="sshpass -p ubuntu $SSHCMD -t ubuntu@10.0.100.3"
    echo "Collecting non-BCPC cookbooks..."
    $BNDO "cd chef-bcpc/cookbooks && tar -cf ../../cookbooks.tar apt chef-client chef-solo-search cron logrotate ntp ubuntu yum"
    echo "Collecting built binaries..."
    $BNDO "cd chef-bcpc/cookbooks/bcpc/files/default && tar -cf ../../../../../bins.tar bins"
    echo "Compressing files..."
    $BNDO "gzip cookbooks.tar bins.tar"
    sshpass -p ubuntu $SCPCMD ubuntu@10.0.100.3:/home/ubuntu/bins.tar.gz ../output
    sshpass -p ubuntu $SCPCMD ubuntu@10.0.100.3:/home/ubuntu/cookbooks.tar.gz ../output
    echo "Removing files from bootstrap node..."
    $BNDO "rm cookbooks.tar.gz bins.tar.gz"
    echo "Finished :"
    ls -l ../output
else
    echo "Fail."
fi
