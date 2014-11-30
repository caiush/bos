#!/bin/bash
#
# A simple tool to check the basics of our cluster - machines up, services running
# This tool uses the cluster hardware list file cluster.txt
#
# The first param specifies the environment
#
# For the second, optional param :
# - if no param is passed, or 'all', all nodes are checked
# - if 'head' is passed only head nodes are checked
# - if 'work' is passed only work nodes are checked
# - if an IP address or hostname is passed, just that node is checked
# 
# If any third param is passed, output is verbose, otherwise only
# output considered an exception is passed. You have to provide a 2nd
# param to allow a 3rd param to be recognized as simple positional
# param processing is used
#
# This may be helpful as a quick check after completing the knife
# bootstrap phase (assigning roles to nodes).
#
#set -x
if [[ -z "$1" ]]; then
    echo "Usage $0 'environment' [role|IP] [verbose]"
    exit
fi
if [[ -z `which fping` ]]; then
    echo "This tool uses fping. You should be able to install fpring with `sudo apt-get install fping`"
    exit
fi

SOCKETDIR=/home/ubuntu/.ssh/sockets
if [[ ! -d $SOCKETDIR ]]; then
    mkdir $SOCKETDIR
fi

SSH_COMMAND_OPTS="-o ControlMaster=auto -o ControlPath=${SOCKETDIR}/%r@%h-%p -o ControlPersist=600"
SSH_COMMON="-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o VerifyHostKeyDNS=no"

echo "$0 : Checking which hosts are online..."
UPHOSTS=`./cluster-whatsup.sh $2`

ENVIRONMENT="$1"
HOSTWANTED="$2"
VERBOSE="$3"
# verbose trace - information that's not normally needed
function vtrace {
    if [[ ! -z "$VERBOSE" ]]; then
        for STR in "$@"; do
            echo -e $STR
        done
    fi
}

# verify we can access the data bag for this environment
KNIFESTAT=`knife data bag show configs $ENVIRONMENT 2>&1 | grep ERROR`
if [[ ! -z "$KNIFESTAT" ]]; then
    echo "knife error $KNIFESTAT when showing the config"
    exit
fi

# get the cobbler root passwd from the data bag
PASSWD=`knife data bag show configs $ENVIRONMENT | grep "cobbler-root-password:" | awk ' {print $2}'`
if [[ -z "$PASSWD" ]]; then
    echo "Failed to retrieve 'cobbler-root-password'"
    exit
fi


declare -A HOSTNAMES

if [[ -f cluster.txt ]]; then
    while read HOSTNAME MACADDR IPADDR ILOIPADDR DOMAIN ROLE; do
        if [[ $HOSTNAME = "end" ]]; then
            continue
        fi
	if [[ "$ROLE" = "bootstrap" ]]; then
	    continue
	fi
	THISUP="false"
	for UPHOST in $UPHOSTS; do
	    if [[ "$IPADDR" = "$UPHOST" ]]; then
		THISUP="true"
		UP=$[UP + 1]
	    fi
	done
        if [[ -z "$HOSTWANTED" || "$HOSTWANTED" = all || "$HOSTWANTED" = "$ROLE" || "$HOSTWANTED" = "$IPADDR" || "$HOSTWANTED" = "$HOSTNAME" ]]; then
	    if [[ "$THISUP" = "false" ]]; then
		echo "$HOSTNAME is down"
		continue
	    else
		vtrace "$HOSTNAME is up"
	    fi
            HOSTS="$HOSTS $IPADDR"
	    IDX=`echo $IPADDR | tr '.' '-'`
	    HOSTNAMES["$IDX"]="$HOSTNAME"
        fi
    done < cluster.txt
    vtrace "HOSTS = $HOSTS"
    echo
    

    for HOST in $HOSTS; do

	# open controller session
	sshpass -p "$PASSWD" ssh $SSH_COMMAND_OPTS $SSH_COMMON -Mn $HOST

	SSH="ssh $SSH_COMMAND_OPTS $SSH_COMMON $HOST"

	echo "Checking name resolution"
	$SSH "grep -m1 server /etc/ntp.conf | cut -f2 -d' ' > /tmp/clusterjunk.txt "
	$SSH  "cat /tmp/clusterjunk.txt | xargs -n1 host"

	echo "checking NTP server"
        $SSH "cat /tmp/clusterjunk.txt | xargs -n1 ping -c 1"

	IDX=`echo $HOST | tr '.' '-'`
	NAME=${HOSTNAMES["$IDX"]}
	vtrace "Checking $NAME ($HOST)..."

	ROOTSIZE=`$SSH "df -k / | grep -v Filesystem"`
	ROOTSIZE=`echo $ROOTSIZE | awk '{print $4}'`
	ROOTGIGS=$((ROOTSIZE/(1024*1024)))
	if [[ $ROOTSIZE -eq 0 ]]; then
	    echo "Root fileystem size = $ROOTSIZE ($ROOTGIGS GB) !!WARNING!!"
	    echo "Machine may still be installing the operating system ... skipping"
	    continue
	elif [[ $ROOTSIZE -lt 100*1024*1024 ]]; then
	    echo "Root fileystem size = $ROOTSIZE ($ROOTGIGS GB) !!WARNING!!"
	else
            vtrace "Root fileystem size = $ROOTSIZE ($ROOTGIGS GB) "
	fi

        if [[ -z `$SSH "ip route show table mgmt | grep default"` ]]; then
            echo "$HOST no mgmt default route !!WARNING!!"
	    BADHOSTS="$BADHOSTS $HOST"
        else
            vtrace "$HOST has a default mgmt route"
            MG=$[MG + 1]
        fi
        if [[ -z `$SSH "ip route show table storage | grep default"` ]]; then
            echo "$HOST has no storage default route !!WARNING!!"
	    BADHOSTS="$BADHOSTS $HOST"
        else
            vtrace "$HOST has a default storage route"
            SG=$[SG + 1]
        fi
        CHEF=`$SSH "which chef-client"`
        if [[ -z "$CHEF" ]]; then
            echo "$HOST doesn't seem to have chef installed so probably hasn't been assigned a role"
            echo
            continue
        fi
        STAT=`$SSH "ceph -s | grep HEALTH"`
        STAT=`echo $STAT | cut -f2 -d:`
        if [[ "$STAT" =~ "HEALTH_OK" ]]; then
            vtrace "$HOST ceph : healthy"
        else
            printf "$HOST %20s %s\n" ceph "$STAT"
        fi
        # fluentd has a ridiculous status output from the normal
        # service reporting (something like "* ruby running"), try to
        # do better, according to this:
        # http://docs.treasure-data.com/articles/td-agent-monitoring
        # Roughly speaking if we have two lines of output from the
        # following ps command it's in good shape, if not dump the
        # entire output of that command to the status. This needs more
        # work
        FLUENTD=`$SSH "ps w -C ruby -C td-agent --no-heading | grep -v chef-client" `
        STAT=`$SSH "ps w -C ruby -C td-agent --no-heading | grep -v chef-client | wc -l" `
        STAT=`echo $STAT | cut -f2 -d:`  
        if [[ "$STAT" =~ 2 ]]; then
            if [[ ! -z "$VERBOSE" ]]; then 
		printf "$HOST %20s %s\n" "fluentd" "normal"
	    fi
        else
            printf "$HOST %20s %s\n" fluentd "$FLUENTD"
        fi
        for SERVICE in keystone glance-api glance-registry cinder-scheduler cinder-volume cinder-api nova-api nova-novncproxy nova-scheduler nova-consoleauth nova-cert nova-conductor nova-compute nova-network haproxy; do
            STAT=`$SSH "service $SERVICE status 2>&1"`
            if [[ ! "$STAT" =~ "unrecognized" ]]; then
                STAT=`echo $STAT | cut -f2 -d":"`
                if [[ ! "$STAT" =~ "start/running" ]]; then
                    printf "$HOST %20s %s\n" "$SERVICE" "$STAT"
		    BADHOSTS="$BADHOSTS $HOST"
                else
            # couldn't get a "verbose printf" function to work
                    if [[ ! -z "$VERBOSE" ]]; then
                        printf "$HOST %20s %s\n" "$SERVICE" "$STAT"
                    fi
                fi
            fi
        done
        echo
	ssh $SSH_COMMAND_OPTS -O exit $HOST
    done
else
    echo "Warning 'cluster.txt' not found"
fi
echo "$ENVIRONMENT cluster summary: $UP hosts up. $MG hosts with default mgmt route. $SG hosts with default storage route"
BADHOSTS=`echo $BADHOSTS | uniq | sort`
if [[ ! -z "$BADHOSTS" ]]; then
    echo "Bad hosts $BADHOSTS - definite issues on these"
fi