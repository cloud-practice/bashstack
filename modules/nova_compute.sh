#!/bin/bash
##########################################################################
# Module:	nova_compute
# Description:	Install Nova Compute Service
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# Install compute service packages (compute node)
yum -y install openstack-nova-compute openstack-utils python-cinder python-cinderclient openstack-neutron-openvswitch

# Create firewall rules
if [[ $firewall == "firewalld" ]] ; then
  # NoVNC 
  firewall-cmd --add-port=5900-5999/tcp
  firewall-cmd --add-port=5900-5999/tcp --permanent
  # VxLAN
  firewall-cmd --add-port=4789/udp
  firewall-cmd --add-port=4789/udp --permanent
elif  [[ $firewall == "iptables" ]] ; then
  iptables -I INPUT -p tcp -m multiport --dports 5900:5999 -m comment --comment "nova compute vnc incoming" -j ACCEPT
  iptables -I INPUT -p udp -m multiport --dports 4789 -m comment --comment "vxlan incoming" -j ACCEPT
  service iptables save; service iptables restart
else
  echo "No firewall rules created as firewalld and iptables are inactive"
fi

# Basic Open vSwitch init
systemctl enable openvswitch
systemctl start openvswitch
ovs-vsctl add-br br-int

# Config Nova Compute
memcnodesarray=($memcache_nodes)
for memcnode in "${memcnodesarray[@]}"
do
  memcstring="${memcstring}${memcnode}:11211,"
done
memcache_nodes_final=$(echo $memcstring | sed 's/,$//')
openstack-config --set /etc/nova/nova.conf DEFAULT memcached_servers ${memcache_nodes_final}

openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address 192.168.1.22X
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://controller-vip.example.com:6080/vnc_auto.html
openstack-config --set /etc/nova/nova.conf database connection mysql://nova:${nova_db_pw}@${mariadb_ip}/nova
openstack-config --set /etc/nova/nova.conf database max_retries -1
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
# Config RabbitMQ Message Broker for Nova 
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend nova.openstack.common.rpc.impl_kombu
if [[ $ha == y ]]; then
  rabbit_nodes_cs=$(sed -e 's/ /,/g' ${rabbit_nodes})
  openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_hosts ${rabbit_nodes_cs}
  openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_ha_queues True
else
  openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_host ${amqp_ip}
  openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_ha_queues False
fi
  openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_port 5672
  openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_userid ${amqp_auth_user}
  openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_pass ${amqp_auth_pw}
#*********** RABBIT SSL SETTINGS ***************
### If SSL enabled on RabbitMQ
#openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_use_ssl True
# openstack-config --set /etc/nova/nova.conf DEFAULT kombu_ssl_certfile /path/to/client.crt
# openstack-config --set /etc/nova/nova.conf DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key
### If Certs Signed by 3rd Party, also add this
#openstack-config --set /etc/nova/nova.conf DEFAULT kombu_ssl_ca_certs /path/to/ca.crt
openstack-config --set /etc/nova/nova.conf DEFAULT metadata_host ${nova_ip}
openstack-config --set /etc/nova/nova.conf DEFAULT metadata_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT metadata_listen_port 8775
openstack-config --set /etc/nova/nova.conf DEFAULT service_neutron_metadata_proxy True
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_metadata_proxy_shared_secret ${neutron_metadata_proxy_shared_secret}
openstack-config --set /etc/nova/nova.conf DEFAULT glance_host ${glance_ip}

openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_url http://${neutron_ip}:9696/
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_tenant_name services
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_username neutron
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_password ${neutron_pw}
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_auth_url http://${keystone_ip}:35357/v2.0
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_vif_driver nova.virt.libvirt.vif.LibvirtGenericVIFDriver
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api neutron
openstack-config --set /etc/nova/nova.conf cinder cinder_catalog_info volume:cinder:internalURL
openstack-config --set /etc/nova/nova.conf conductor use_local false
openstack-config --set /etc/nova/nova.conf DEFAULT scheduler_host_subset_size 30
if [[ $glance_backend="nfs" ]]; then
  openstack-config --set /etc/nova/nova.conf libvirt nfs_mount_options v3
fi

## NOTE - Need to update backend to account for other glance types 

## NOTE - Need to add live migration support

openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host ${keystone_ip}
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://${keystone_ip}:5000/
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password ${nova_pw}
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name services


# Configure Neutron on Compute Node


#### UPDATE HERE
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_host ${keystone_ip}
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_password ${neutron_pw}
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
openstack-config --set /etc/neutron/neutron.conf DEFAULT notification_driver neutron.openstack.common.notifier.rpc_notifier


# OVS Plugin Configuration
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent tunnel_types vxlan
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent vxlan_udp_port 4789
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs enable_tunneling True
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs tunnel_id_ranges 1:1000
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs tenant_network_type vxlan
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs integration_bridge br-int
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs tunnel_bridge br-tun
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs local_ip 192.168.1.22X
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent l2_population False






# Launch the compute service 
systemctl enable messagebus
systemctl start messagebus
systemctl enable libvirtd
systemctl start libvirtd
systemctl enable openstack-nova-compute
systemctl start openstack-nova-compute


# -optional-  nova networking
#systemctl enable openstack-nova-network
#systemctl start openstack-nova-network


