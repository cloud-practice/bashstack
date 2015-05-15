#!/bin/bash
##########################################################################
# Module:	heat_step2
# Description:	Sets up HA if applicable and starts Heat
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

if [[ $ha == "y" ]]; then
  if [[ $ha_type == "pacemaker" ]] ; then
    if [[ $(hostname -s) == $heat_bootstrap_node ]]; then
      pcs resource create heat-api systemd:openstack-heat-api --clone interleave=true
      pcs resource create heat-api-cfn systemd:openstack-heat-api-cfn  --clone interleave=true
      pcs resource create heat-api-cloudwatch systemd:openstack-heat-api-cloudwatch --clone interleave=true
      pcs resource create heat-engine systemd:openstack-heat-engine --clone interleave=true

      pcs constraint order start heat-api-clone then heat-api-cfn-clone
      pcs constraint colocation add heat-api-cfn-clone with heat-api-clone
      pcs constraint order start heat-api-cfn-clone then heat-api-cloudwatch-clone
      pcs constraint colocation add heat-api-cloudwatch-clone with heat-api-cfn-clone
      pcs constraint order start heat-api-cloudwatch-clone then heat-engine-clone
      #### NOTE: For Juno / OSP 6 active/passive was still standard ####
      pcs constraint colocation add heat-engine-clone with heat-api-cloudwatch-clone
      if [[ $heat_nodes == $ceilometer_nodes ]] ; then
        pcs constraint order start ceilometer-notification-clone then heat-api-clone
      fi
    fi
  elif [[ $ha_type == "keepalived" ]] ; then
    # Launch the Orchestration Service
    systemctl enable openstack-heat-api
    systemctl enable openstack-heat-api-cfn
    systemctl enable openstack-heat-api-cloudwatch
    systemctl enable openstack-heat-engine
    systemctl start openstack-heat-api
    systemctl start openstack-heat-api-cfn
    systemctl start openstack-heat-api-cloudwatch
    systemctl start openstack-heat-engine
  else
    echo "HA Type not specified"
  fi
else
  # Launch the Orchestration Service
  systemctl enable openstack-heat-api
  systemctl enable openstack-heat-api-cfn
  systemctl enable openstack-heat-api-cloudwatch
  systemctl enable openstack-heat-engine
  systemctl start openstack-heat-api
  systemctl start openstack-heat-api-cfn
  systemctl start openstack-heat-api-cloudwatch
  systemctl start openstack-heat-engine
fi


