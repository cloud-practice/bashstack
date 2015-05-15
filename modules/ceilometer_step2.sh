#!/bin/bash
##########################################################################
# Module:	ceilometer_step2.sh
# Description:	Configure HA if applicable and start Ceilometer 
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

if [[ $ha == "y" ]]; then
  if [[ $ha_type == "pacemaker" ]]; then
    if [[ $(hostname -s) == $ceilometer_bootstrap_node ]]; then
      pcs resource create ceilometer-central systemd:openstack-ceilometer-central --clone interleave=true
      pcs resource create ceilometer-collector systemd:openstack-ceilometer-collector --clone interleave=true
      pcs resource create ceilometer-api systemd:openstack-ceilometer-api --clone interleave=true
      pcs resource create ceilometer-delay Delay startdelay=10 --clone interleave=true
      pcs resource create ceilometer-alarm-evaluator systemd:openstack-ceilometer-alarm-evaluator --clone interleave=true
      pcs resource create ceilometer-alarm-notifier systemd:openstack-ceilometer-alarm-notifier --clone interleave=true
      pcs resource create ceilometer-notification systemd:openstack-ceilometer-notification  --clone interleave=true

      if [[ $redis_nodes == $ceilometer_nodes ]] ; then
        pcs constraint order start vip-redis then ceilometer-central-clone
      fi

      pcs constraint order start ceilometer-central then ceilometer-collector-clone
      pcs constraint order start ceilometer-collector-clone then ceilometer-api-clone
      pcs constraint colocation add ceilometer-api-clone with ceilometer-collector-clone 
      pcs constraint order start ceilometer-api-clone then ceilometer-delay-clone
      pcs constraint colocation add ceilometer-delay-clone with ceilometer-api-clone
      pcs constraint order start ceilometer-delay-clone then ceilometer-alarm-evaluator-clone
      pcs constraint colocation add ceilometer-alarm-evaluator-clone with ceilometer-delay-clone
      pcs constraint order start ceilometer-alarm-evaluator-clone then ceilometer-alarm-notifier-clone
      pcs constraint colocation add ceilometer-alarm-notifier-clone with ceilometer-alarm-evaluator-clone
      pcs constraint order start ceilometer-alarm-notifier-clone then ceilometer-notification-clone
      pcs constraint colocation add ceilometer-notification-clone with ceilometer-alarm-notifier-clone

      if [[ $mongo_nodes == $ceilometer_nodes ]] ; then
        pcs constraint order start mongodb-clone then ceilometer-central
      fi
      if [[ $keystone_nodes == $ceilometer_nodes ]] ; then
        pcs constraint order start keystone-clone then ceilometer-central
      fi
    fi
    
  elif [[ $ha_type == "keepalived" ]]; then
    # Start and Enable Ceilometer Services
    systemctl enable openstack-ceilometer-central
    systemctl enable openstack-ceilometer-collector
    systemctl enable openstack-ceilometer-api
    systemctl enable openstack-ceilometer-alarm-evaluator
    systemctl enable openstack-ceilometer-alarm-notifier
    systemctl enable openstack-ceilometer-notification
    systemctl start openstack-ceilometer-central
    systemctl start openstack-ceilometer-collector
    systemctl start openstack-ceilometer-api
    systemctl start openstack-ceilometer-alarm-evaluator
    systemctl start openstack-ceilometer-alarm-notifier
    systemctl start openstack-ceilometer-notification
  else
    echo "HA Type not specified"
else
  # Start and Enable Ceilometer Services
  systemctl enable openstack-ceilometer-central
  systemctl enable openstack-ceilometer-collector
  systemctl enable openstack-ceilometer-api
  systemctl enable openstack-ceilometer-alarm-evaluator
  systemctl enable openstack-ceilometer-alarm-notifier
  systemctl enable openstack-ceilometer-notification
  systemctl start openstack-ceilometer-central
  systemctl start openstack-ceilometer-collector
  systemctl start openstack-ceilometer-api
  systemctl start openstack-ceilometer-alarm-evaluator
  systemctl start openstack-ceilometer-alarm-notifier
  systemctl start openstack-ceilometer-notification
fi
