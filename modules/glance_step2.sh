#!/bin/bash
##########################################################################
# Module:	glance
# Description:	Run after install and backend config to start glance / HA
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

if [[ $ha == "y" ]]; then
  if [[ $ha_type == "pacemaker" ]]; then
    if [[ $(hostname -s) == $glance_bootstrap_node ]]; then
      pcs resource create glance-registry systemd:openstack-glance-registry --clone
      pcs resource create glance-api systemd:openstack-glance-api --clone

      if [[ $glance_backend == "nfs" ]] ; then
        pcs constraint order start glance-fs-clone then glance-registry-clone
        pcs constraint colocation add glance-registry-clone with glance-fs-clone
      fi
      pcs constraint order start glance-registry-clone then glance-api-clone
      pcs constraint colocation add glance-api-clone with glance-registry-clone
      pcs constraint order start keystone-clone then glance-registry-clone

  elif [[ $ha_type == "keepalived" ]]; then
    systemctl start openstack-glance-registry
    systemctl start openstack-glance-api
    systemctl enable openstack-glance-registry
    systemctl enable openstack-glance-api
  else
    echo "HA Type not Specified"
  fi
else
  # Non-HA: Start and enable glance services 
  systemctl enable openstack-glance-registry
  systemctl enable openstack-glance-api
  systemctl start openstack-glance-registry
  systemctl start openstack-glance-api
fi

