#!/bin/bash
##########################################################################
# Module:	neutron
# Description:	Install Neutron Networking 
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

yum -y install openstack-neutron openstack-utils openstack-selinux
yum -y install openstack-neutron-openvswitch openstack-neutron-ml2

# Firewall rules for neutron
if [[ $firewall == "firewalld" ]] ; then
  # Neutron Server API
  firewall-cmd --add-port=9696/tcp
  firewall-cmd --add-port=9696/tcp --permanent
  # VxLAN
  firewall-cmd --add-port=4789/udp
  firewall-cmd --add-port=4789/udp --permanent
elif  [[ $firewall == "iptables" ]] ; then
  iptables -I INPUT -p tcp -m multiport --dports 9696 -m comment --comment "neutron api incoming" -j ACCEPT
  iptables -I INPUT -p udp -m multiport --dports 4789 -m comment --comment "VxLAN incoming" -j ACCEPT

  # IS THIS NEEDED?? 
  # -A INPUT -p gre -j ACCEPT
  # -A OUTPUT -p gre -j ACCEPT

  service iptables save; service iptables restart
else
  echo "No firewall rules created as firewalld and iptables are inactive"
fi

if [ ! -f /root/.my.cnf ] ; then    # Need password-less mysql access
  echo "ERROR - /root/.my.cnf doesn't exist" 
  exit 1
fi

if [[ $(hostname -s) == $neutron_bootstrap_node ]]; then
  # Create the Neutron Database
  mysql -u root << EOF
CREATE DATABASE neutron character set utf8;
GRANT ALL ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '${neutron_db_pw}';
GRANT ALL ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '${neutron_db_pw}';
FLUSH PRIVILEGES;
quit
EOF

  # Configure Neutron to auth through keystone
  source ~/keystonerc_admin
  keystone user-create --name neutron --pass ${neutron_pw}
  keystone user-role-add --user neutron --role admin --tenant services
  keystone service-create --name neutron --type network --description "OpenStack Networking Service"
  keystone endpoint-create --service neutron --publicurl "http://${neutron_ip_public}:9696" --adminurl "http://${neutron_ip_admin}:9696" --internalurl "http://${neutron_ip_internal}:9696"
fi

# Configure Neutron
openstack-config --set /etc/neutron/neutron.conf DEFAULT bind_host $(ip addr show dev ${neutron_bind_nic} scope global | grep dynamic| sed -e 's#.*inet ##g' -e 's#/.*##g')

# Configure Neutron Auth through keystone
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_host ${keystone_ip}
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_password ${neutron_pw}
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://$keystone_ip:5000/

# Configure authtoken in api-paste
openstack-config --set /etc/neutron/api-paste.conf filter:authtoken auth_host ${keystone_ip}
openstack-config --set /etc/neutron/api-paste.conf filter:authtoken auth_port 35357
openstack-config --set /etc/neutron/api-paste.conf filter:authtoken auth_protocol http
openstack-config --set /etc/neutron/api-paste.conf filter:authtoken auth_uri http://${keystone_ip}:5000/
openstack-config --set /etc/neutron/api-paste.conf filter:authtoken admin_user neutron
openstack-config --set /etc/neutron/api-paste.conf filter:authtoken admin_tenant_name services
openstack-config --set /etc/neutron/api-paste.conf filter:authtoken admin_password ${neutron_pw}

# Configure DB Connection
openstack-config --set /etc/neutron/neutron.conf database connection mysql://neutron:${neutron_db_pw}@${mariadb_ip}/neutron
openstack-config --set /etc/neutron/neutron.conf database max_retries -1

# Configure RabbitMQ
openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend neutron.openstack.common.rpc.impl_kombu
if [[ $ha == y ]]; then
  rabbit_nodes_cs=$(sed -e 's/ /,/g' ${rabbit_nodes})
  openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_hosts ${rabbit_nodes_cs}
  openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_ha_queues True
else
  openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_host ${amqp_ip}
  openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_ha_queues False
fi
openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_port 5672
openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_userid ${amqp_auth_user}
openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_pass ${amqp_auth_pw}
### If SSL enabled on RabbitMQ
# openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_use_ssl True
# openstack-config --set /etc/neutron/neutron.conf DEFAULT kombu_ssl_certfile /path/to/client.crt
# openstack-config --set /etc/neutron/neutron.conf DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key
### If Certs Signed by 3rd Party, also add this
#openstack-config --set /etc/neutron/neutron.conf DEFAULT kombu_ssl_ca_certs /path/to/ca.crt

openstack-config --set /etc/neutron/neutron.conf DEFAULT notification_driver neutron.openstack.common.notifier.rpc_notifier
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_url http://${nova_ip}:8774/v2
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_region_name RegionOne

openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_tenant_id $(keystone tenant-get services |grep id | awk '{print $4}')

openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_username nova
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_password ${nova_pw}

openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_auth_url http://${keystone_ip}:35357/v2.0

openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes  True
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes  True
# Create services / agents
service_plugins=""
if [[ $use_neutron_l3 == "y" ]]; then
  service_plugins="$service_plugins,router"
  openstack-config --set /etc/neutron/neutron.conf DEFAULT router_scheduler_driver neutron.scheduler.l3_agent_scheduler.ChanceScheduler
  if [[ $l3_ha == "y" ]]; then
    l3_ha_value="True"
  else
    l3_ha_value="False"
  fi
  openstack-config --set /etc/neutron/neutron.conf DEFAULT l3_ha ${l3_ha_value}
  openstack-config --set /etc/neutron/neutron.conf DEFAULT min_l3_agents_per_router 2
  openstack-config --set /etc/neutron/neutron.conf DEFAULT max_l3_agents_per_router 2
  openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
  openstack-config --set /etc/neutron/l3_agent.ini DEFAULT handle_internal_only_routers True
  openstack-config --set /etc/neutron/l3_agent.ini DEFAULT send_arp_for_ha 3
  openstack-config --set /etc/neutron/l3_agent.ini DEFAULT router_delete_namespaces False
  openstack-config --set /etc/neutron/l3_agent.ini DEFAULT metadata_ip ${nova_ip}
  openstack-config --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge ${neutron_external_network_bridge}


fi
if [[ $use_neutron_fwaas == "y" ]]; then
  service_plugins="$service_plugins,firewall"
  openstack-config --set /etc/neutron/fwaas_driver.ini fwaas enabled True
  openstack-config --set /etc/neutron/fwaas_driver.ini fwaas driver neutron.services.firewall.drivers.linux.iptables_fwaas.IptablesFwaasDriver
fi
if [[ $use_neutron_lbaas == "y" ]]; then
  yum -y install haproxy
  service_plugins="$service_plugins,lbaas"
  openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
  openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT device_driver neutron.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver
  openstack-config --set /etc/neutron/lbaas_agent.ini haproxy user_group haproxy 
fi
if [[ $use_neutron_vpnaas == "y" ]]; then
  service_plugins="$service_plugins,vpnaas"
fi
if [[ $use_neutron_metering == "y" ]]; then
  yum -y install openstack-neutron-metering-agent
  service_plugins="$service_plugins,metering"
fi
if [[ $use_neutron_metadata == "y" ]]; then
  openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_strategy keystone
  openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://${keystone_ip}:35357/v2.0
  openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_host ${keystone_ip}
  openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_region RegionOne
  openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name services
  openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_user neutron
  openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_password ${neutron_pw}
  openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip ${nova_ip}
  openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_port 8775
  openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret ${neutron_metadata_proxy_shared_secret}
  openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_workers 4
  openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_backlog 2048
fi
if [[ $use_neutron_dhcp == "y" ]]; then
  # DHCP agents should equal number of neutron nodes
  dhcp_agents=$(echo $neutron_nodes | wc -w)
  openstack-config --set /etc/neutron/neutron.conf DEFAULT dhcp_agents_per_network ${dhcp_agents}
  openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
  openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_delete_namespaces False
  if [[ $neutron_dnsmasq_mtu != "" ]]; then
    echo "dhcp-option-force=26,${neutron_dnsmasq_mtu}" > /etc/neutron/dnsmasq-neutron.conf
    chown root:neutron /etc/neutron/dnsmasq-neutron.conf
    chmod 644 /etc/neutron/dnsmasq-neutron.conf
  fi
fi
service_plugins_final=$(echo $service_plugins | sed 's/^,//')
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins $service_plugins_final

if [[ ${neutron_l2_plugin} == "ml2" ]] ; then
  openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin  neutron.plugins.ml2.plugin.Ml2Plugin

  openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini type_drivers ${neutron_ml2_type_drivers}
  openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types ${neutron_ml2_tenant_network_types}
  openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers ${neutron_ml2_mechanism_drivers}
  openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks ${neutron_ml2_network_flat_networks}
  openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges ${neutron_ml2_gre_tunnel_id_ranges}
  openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges ${neutron_ml2_vxlan_vni_ranges}
  openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vxlan_group ${neutron_ml2_vxlan_group}
  openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True

  ln -sf /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
else
  echo "ERROR: No L2 plugin implemented except ML2"
fi

if [[ $(hostname -s) == $neutron_bootstrap_node ]]; then
  # Populate the database - including L2 plugin 
  neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini upgrade head

  # Start/Stop Neutron Service
  systemctl start neutron-server
  systemctl stop neutron-server
fi


# Setup openvswitch agent
yum -y install openstack-neutron openstack-neutron-openvswitch openvswitch
systemctl enable openvswitch
systemctl start openvswitch

ovs-vsctl add-br br-int
ovs-vsctl add-br ${neutron_external_network_bridge}

ovs-vsctl add-port ${neutron_external_network_bridge} ${neutron_ovs_bridge_iface}

### ADD STEPS TO MOVE IP ADDRESS TO BRIDGE HERE...

openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent tunnel_types ${neutron_agent_tunnel_types}
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent vxlan_udp_port 4789
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs local_ip  $(ip addr show dev ${neutron_ovs_tunnel_iface} scope global | grep dynamic| sed -e 's#.*inet ##g' -e 's#/.*##g')
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs integration_bridge br-int
if [[ $(echo ${neutron_ml2_type_drivers} | egrep -i "gre|vxlan" | wc -l) -gt 0 ]]; then
  openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs enable_tunneling True
  openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs tunnel_bridge br-tun
fi
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs bridge_mappings ${neutron_ovs_bridge_mappings}
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

if [[ ${neutron_l2_population} == "y" ]] && [[ ${neutron_l3_ha} == "n" ]]; then
  openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent l2_population True
else
  openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent l2_population False
fi








