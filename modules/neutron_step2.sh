#!/bin/bash
##########################################################################
# Module:	neutron_step2
# Description:	Install Neutron Networking 
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

if [[ $ha == "y" ]] ; then
  if [[ $ha_type == "pacemaker" ]]; then
    if [[ $(hostname -s) == $neutron_bootstrap_node ]]; then
      # Neutron Server
      pcs resource create neutron-server systemd:neutron-server op start timeout=90 --clone interleave=true
      if [[ $keystone_nodes == $neutron_nodes ]]; then
        pcs constraint order start keystone-clone then neutron-server-clone
      fi
      
      # Neutron Agents 

      # For A/P, set clone-max=1
      pcs resource create neutron-scale ocf:neutron:NeutronScale --clone globally-unique=true clone-max=3 interleave=true

      pcs resource create neutron-ovs-cleanup ocf:neutron:OVSCleanup --clone interleave=true
      pcs resource create neutron-netns-cleanup ocf:neutron:NetnsCleanup --clone interleave=true
      pcs resource create neutron-openvswitch-agent  systemd:neutron-openvswitch-agent --clone interleave=true
      if [[ $use_neutron_dhcp == "y" ]]; then 
        pcs resource create neutron-dhcp-agent systemd:neutron-dhcp-agent --clone interleave=true
      fi
      if [[ $use_neutron_l3 == "y" ]]; then
        pcs resource create neutron-l3-agent systemd:neutron-l3-agent --clone interleave=true
      fi
      if [[ $use_neutron_metadata == "y" ]]; then
        pcs resource create neutron-metadata-agent systemd:neutron-metadata-agent  --clone interleave=true
      fi
      pcs constraint order start neutron-scale-clone then neutron-ovs-cleanup-clone
      pcs constraint colocation add neutron-ovs-cleanup-clone with neutron-scale-clone
      pcs constraint order start neutron-ovs-cleanup-clone then neutron-netns-cleanup-clone
      pcs constraint colocation add neutron-netns-cleanup-clone with neutron-ovs-cleanup-clone
      pcs constraint order start neutron-netns-cleanup-clone then neutron-openvswitch-agent-clone
      pcs constraint colocation add neutron-openvswitch-agent-clone with neutron-netns-cleanup-clone
      if [[ $use_neutron_dhcp == "y" ]]; then
        pcs constraint order start neutron-openvswitch-agent-clone then neutron-dhcp-agent-clone
        pcs constraint colocation add neutron-dhcp-agent-clone with neutron-openvswitch-agent-clone
      fi
      if [[ $use_neutron_dhcp == "y" ]] && [[ $use_neutron_l3 == "y" ]]; then
        pcs constraint order start neutron-dhcp-agent-clone then neutron-l3-agent-clone
        pcs constraint colocation add neutron-l3-agent-clone with neutron-dhcp-agent-clone
      fi
      if [[ $use_neutron_metadata == "y" ]] && [[ $use_neutron_l3 == "y" ]]; then
        pcs constraint order start neutron-l3-agent-clone then neutron-metadata-agent-clone
        pcs constraint colocation add neutron-metadata-agent-clone with neutron-l3-agent-clone
      fi

      pcs constraint order start neutron-server-clone then neutron-scale-clone
 
    fi
  elif [[ $ha_type == "keepalived" ]]; then
    systemctl start neutron-openvswitch-agent
    systemctl enable neutron-openvswitch-agent
    systemctl enable neutron-ovs-cleanup
    if [[ $neutron_use_dhcp == "y" ]]; then
      systemctl start neutron-dhcp-agent
      systemctl enable neutron-dhcp-agent
    fi
    if [[ $neutron_use_l3 == "y" ]]; then
      systemctl start neutron-l3-agent
      systemctl enable neutron-l3-agent
    fi
    if [[ $neutron_use_metadata == "y" ]] ; then
      systemctl start neutron-metadata-agent
      systemctl enable neutron-metadata-agent
    fi
    if [[ $neutron_use_lbaas == "y" ]]; then
      systemctl start neutron-lbaas-agent
      systemctl enable neutron-lbaas-agent
    fi

    # Ensure neutron restarts in the event it times out waiting for Galera
    cat << EOF > /etc/systemd/sytem/neutron-server.service.d/restart.conf
[Service]
Restart=on-failure
EOF
  else
    echo "HA Type not specified"
  fi
else
  # No HA
  systemctl start neutron-openvswitch-agent
  systemctl enable neutron-openvswitch-agent
  systemctl enable neutron-ovs-cleanup
  if [[ $neutron_use_dhcp == "y" ]]; then
    systemctl start neutron-dhcp-agent
    systemctl enable neutron-dhcp-agent
  fi
  if [[ $neutron_use_l3 == "y" ]]; then
    systemctl start neutron-l3-agent
    systemctl enable neutron-l3-agent
  fi

  if [[ $neutron_use_metadata == "y" ]] ; then
    systemctl start neutron-metadata-agent
    systemctl enable neutron-metadata-agent
  fi
  if [[ $neutron_use_lbaas == "y" ]]; then
    systemctl start neutron-lbaas-agent
    systemctl enable neutron-lbaas-agent
  fi

    # Ensure neutron restarts in the event it times out waiting for Galera
    cat << EOF > /etc/systemd/sytem/neutron-server.service.d/restart.conf
[Service]
Restart=on-failure
EOF

fi

