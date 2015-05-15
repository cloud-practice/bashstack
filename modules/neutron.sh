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

fi
if [[ $use_neutron_fwaas == "y" ]]; then
  service_plugins="$service_plugins,firewall"
  openstack-config --set /etc/neutron/fwaas_driver.ini fwaas enabled True
  openstack-config --set /etc/neutron/fwaas_driver.ini fwaas driver neutron.services.firewall.drivers.linux.iptables_fwaas.IptablesFwaasDriver
fi
if [[ $use_neutron_lbaas == "y" ]]; then
  service_plugins="$service_plugins,lbaas"
  openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
  openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT device_driver neutron.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver
  openstack-config --set /etc/neutron/lbaas_agent.ini haproxy user_group haproxy 
fi
if [[ $use_neutron_vpnaas == "y" ]]; then
  service_plugins="$service_plugins,vpnaas"
fi
if [[ $use_neutron_metering == "y" ]]; then
  service_plugins="$service_plugins,metering"
fi
if [[ $use_neutron_metadata == "y" ]]; then
fi
if [[ $use_neutron_dhcp == "y" ]]; then
  # DHCP agents should equal number of neutron nodes
  dhcp_agents=$(echo $neutron_nodes | wc -w)
  openstack-config --set /etc/neutron/neutron.conf DEFAULT dhcp_agents_per_network ${dhcp_agents}
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



################ LEFT OFF HERE ##################











# Tunnel config -- Need to validate this as the example configures an OVS-BR0 bridge....  Note - This results in 2 instances sharing a layer 2 network
# On each host create a virtual bridge
ovs-vsctl add-br OVS-BR0

# GRE Example to link hosts
  # From Host 1:
  ovs-vsctl add-port OVS-BR0 gre1 -- set Interface gre1 type=gre options:remote_ip=192.168.1.11
  # From Host 2: 
  ovs-vsctl add-port OVS-BR0 gre1 -- set Interface gre1 type=gre options:remote_ip=192.168.1.10

# VxLAN Example to link hosts
ovs-vsctl add-port OVS-BR0 vxlan1 -- set Interface vxlan1 type=vxlan options:remote_ip=192.168.1.11
ovs-vsctl add-port OVS-BR0 vxlan1 -- set Interface vxlan1 type=vxlan options:remote_ip=192.168.1.10




# Populate the database - including L2 plugin 
neutron-db-manage --config-file /usr/share/neutron/neutron-dist.conf --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini upgrade head

# Start/Enable Neutron Service
systemctl start neutron-server
systemctl enable neutron-server

# Configure the DHCP Agent 
# Configure the interface driver
  # If OVS
  openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
  # If Linux Bridge
  openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver

  # Start the DHCP Agent 
  systemctl enable neutron-dhcp-agent
  systemctl start neutron-dhcp-agent

# Connecting an external provider network:
#source ~/keystonerc_admin
#neutron net-create EXTERNAL_NAME --router:external True --provider:network_type TYPE --provider:physical_network PHYSNET --provider:segmentation_id VLAN_TAG
#neutron subnet-create --gateway GATEWAY --allocation-pool start=IP_RANGE_START,end=IP_RANGE_END --disable-dhcp EXTERNAL_NAME EXTERNAL_CIDR
#neutron router-create NAME
#neutron router-gateway-set ROUTER NETWORK
#neutron router-interface-add ROUTER SUBNET
# Configuring the Plug-in Agent 
  # If Open vSwitch
  # verify packages installed
  yum -y install openvswitch openstack-neutron-openvswitch
  systemctl start openvswitch
  systemctl enable openvswitch
  # Create integration bridge
  ovs-vsctl add-br br-int
  # Add bridge mappings within the network_vlan_ranges  (PHYSNET:BRIDGE)
  openstack-config --set /etc/neutron/plugin.ini OVS bridge_mappings MAPPINGS

  # Start and Enable Agents 
  systemctl start neutron-openvswitch-agent
  systemctl enable neutron-openvswitch-agent
  systemctl enable neutron-ovs-cleanup

  # If Linux Bridge
  yum -y install openstack-neutron-linuxbridge
  # Add bridge mappings within the network_vlan_ranges  (PHYSNET:BRIDGE)
  openstack-config --set /etc/neutron/plugin.ini LINUX_BRIDGE physical_interface_mappings MAPPINGS
  systemctl enable neutron-linuxbridge-agent
  systemctl start neutron-linuxbridge-agent

# Configure the Metadata Agent
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_host ${keystone_ip}
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_url http://${keystone_ip}:35357/v2.0
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name services
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_user neutron
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_password ${neutron_pw}
#### Set nova_metadata_ip or nova_metadata_port???  Packstack seems to...
### Update 'metadata_workers'?  This is set to 0 in packstack install 

# Configure the L3 Agent
  # Configure interface driver for L3
  # Open vSwitch
  openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
  # Linux Bridge
  openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver

  # Configure external network access
  ovs-vsctl add-br br-ex
  /etc/sysconfig/network-scripts/ifcfg-br-ex
DEVICE=br-ex
DEVICETYPE=ovs
TYPE=OVSBridge
ONBOOT=yes
BOOTPROTO=none

  openstack-config --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge br-ex
  # Or if using a provider network: 
  #openstack-config --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge ""

# Start the L3 agent 
systemctl enable neutron-l3-agent
systemctl start neutron-l3-agent

# Start the Metadata Agent 
systemctl enable neutron-metadata-agent
systemctl start neutron-metadata-agent

### Least router scheduler -- rescheduling routers?? 
# neutron.conf: router_scheduler_driver=neutron.scheduler.l3_agent_scheduler.LeastRoutersScheduler
#neutron l3-agent-router-remove [l3 node] [router]
#neutron l3-agent-router-add [l3 node] [router]

# Validation 
openstack-status | grep neutron-server
openstack-status | egrep "neutron-openvswitch-agent|neutron-linuxbridge-agent|neutron-metadata-agent|neutron-dhcp-agent|neutron-l3-agent"

### NEED MORE VALIDATION OF NETWORKING THAN THIS! 


## WHERE IS THE openstack-neutron-metering-agent????



