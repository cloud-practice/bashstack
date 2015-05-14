#!/bin/bash
##########################################################################
# Module:	rabbitmq_cluster
# Description:	Bootstrap Cluster after installing RabbitMQ
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# Only execute this for HA deployments
if [[ $ha == "y" ]]; then

  # Copy erlang cookie from bootstrap node to others
  if [[ $(hostname -s) == $rabbit_bootstrap_node ]]; then
    for node in $rabbit_nodes
    do
      if [[ $node != $(hostname -s) ]]; then 
        scp -p /var/lib/rabbitmq/.erlang.cookie $node:/var/lib/rabbitmq
      fi
    done
  fi

  if [[ $ha_type == "pacemaker" ]]; then
    systemctl disable rabbitmq-server.service
    if [[ $(hostname -s) == $rabbit_bootstrap_node ]]; then
       pcs resource create rabbitmq-server rabbitmq-cluster set_policy='HA ^(?!amq\.).* {"ha-mode":"all"}' --clone ordered=true interleave=true      
    fi

  elif [[ $ha_type == "keepalived" ]]; then
    systemctl start rabbitmq-server.service
    rabbitmqctl set_policy HA '^(?!amq\.).*' '{"ha-mode": "all"}'
  else
    echo "No HA Type Specified"
    exit 1
fi

