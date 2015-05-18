#!/bin/bash
##########################################################################
# Module:	cinder_step2
# Description:	Start Cinder Block Storage Service
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

if [[ $ha == "y" ]] ; then
  if [[ $ha_type == "pacemaker" ]]; then
    # Setup false host name for cinder active/passive HA
    openstack-config --set /etc/cinder/cinder.conf DEFAULT host rhos6-cinder
    if [[ $(hostname -s) == $neutron_bootstrap_node ]]; then
      # create services in pacemaker
      pcs resource create cinder-api systemd:openstack-cinder-api --clone interleave=true
      pcs resource create cinder-scheduler systemd:openstack-cinder-scheduler --clone interleave=true

      # Volume must be A/P for now. See https://bugzilla.redhat.com/show_bug.cgi?id=1193229
      pcs resource create cinder-volume systemd:openstack-cinder-volume

      pcs constraint order start cinder-api-clone then cinder-scheduler-clone
      pcs constraint colocation add cinder-scheduler-clone with cinder-api-clone
      pcs constraint order start cinder-scheduler-clone then cinder-volume
      pcs constraint colocation add cinder-volume with cinder-scheduler-clone
     
      if [[ $cinder_nodes == $keystone_nodes ]]; then
        pcs constraint order start keystone-clone then cinder-api-clone
      fi
    fi
  elif [[ $ha_type == "keepalived" ]]; then
    systemctl start openstack-cinder-api
    systemctl start openstack-cinder-scheduler
    systemctl start openstack-cinder-volume
    systemctl enable openstack-cinder-api
    systemctl enable openstack-cinder-scheduler
    systemctl enable openstack-cinder-volume
    # Note - cinder-volume should not be active/active in Juno
    # https://bugzilla.redhat.com/show_bug.cgi?id=1193229
  else
    echo "HA Type not specified" 
  fi

else
  # Start and enable Cinder services
  systemctl enable openstack-cinder-api
  systemctl enable openstack-cinder-scheduler
  systemctl enable openstack-cinder-volume
  systemctl start openstack-cinder-api
  systemctl start openstack-cinder-scheduler
  systemctl start openstack-cinder-volume
fi 
