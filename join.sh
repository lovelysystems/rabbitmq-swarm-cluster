#!/bin/bash
#
# Script to join rabbitmq cluster.
#
# This script is call in background once the mangement ui of this node is
# running (see Dockerfile).
#
#

# Wait a random amount of seconds (between 1 and 10 seconds) to get in
# parallel started instances a littel bit out of sync.
echo "Wait random duration..."
sleep $[ ( $RANDOM % 10 )  + 10 ]s

echo "Try to join rabbitmq cluster..."


# Try to determine all hosts of this service (given by env var `SERVICE_NAME`).
# host command required, provided by bind-tools package
# Remove ourselves from list
hostIps=($(host tasks.$SERVICE_NAME | awk '{print $4}'))
nodes=()
for hostIp in ${hostIps[@]}
do
  echo "checking $hostIp"
  myIp=$(ip a | grep inet | grep $hostIp | wc -l)
  echo "myIp = $myIp"
  if [ $myIp == 0 ]; then
    hostName=$(host $hostIp | awk '{print $NF}' | cut -d. -f1-3)
    echo "adding $hostName"
    nodes+=($hostName)
  fi
done


# If the service is configured with just one replica this rabbitmq instance is
# running in standalone mode and no further cluster joining arithmetic is
# required. If there are multiple nodes configured stop the app to start
# setting up a cluster.
echo
if [[ ${#nodes} > 0 ]]
then
  echo "Found nodes of cluster:"
  echo $nodes
  rabbitmqctl stop_app
  rabbitmqctl reset
else
  echo "Found standalone setup."
  exit 0
fi
echo

# Join cluster by trying one node after each other. If successfully joined, start the rabbitmq
# app again
while true
do
    for node in $nodes
    do
        # manually force a start by setting the env variable FORCE_START
        if [[ -f /tmp/FORCE_START ]]
        then
            echo "Startup forced manually."
            echo
            rabbitmqctl start_app
            exit 0
        fi
        # if peer is reachable try to join the cluster of that host
        echo "Try to reach $node"
        if nc -z "$node" 15672
        then
            rabbitmqctl join_cluster rabbit@$node
            if [[ $? == "0" ]]
            then
                echo
                echo "Start app after joining cluster"

                rabbitmqctl start_app

                echo
                echo "Try to cleanup old nodes of same slot..."
                for n in `rabbitmqctl cluster_status | awk '/disc/,/]}]}/' | grep -o "$SERVICE_NAME[^']*"`
                do
                    if [[ $n == "$SERVICE_NAME.$SLOT."* && $n != $HOSTNAME  ]]
                    then
                        echo
                        echo "removing node $n from cluster"
                        rabbitmqctl forget_cluster_node rabbit@$n
                    fi
                done
                echo
                echo "Successfully joined cluster"
                exit 0
            fi
        elif [[ "$SLOT" == "$MASTER_SLOT" ]]
        then
            echo "Startup due to claimed master role on slot $MASTER_SLOT."
            echo
            rabbitmqctl start_app
            exit 0
        fi
    done

    sleep 10
done

echo "Failed to join cluster."
exit 1
