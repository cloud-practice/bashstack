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
yum -y install openstack-nova-compute python-cinderclient


# Config compute authentication
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host ${keystone_ip}
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://${keystone_ip}:5000/
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password ${nova_pw}
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name services

# Configure nova database connection
openstack-config --set /etc/nova/nova.conf DEFAULT sql_connection mysql://nova:${nova_db_pw}@${mariadb_ip}/nova


# Config RabbitMQ Message Broker for Nova 
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend nova.openstack.common.rpc.impl_kombu
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_host ${amqp_ip}
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_port 5672
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_userid ${amqp_auth_user}
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_pass ${amqp_auth_pw}
#*********** RABBIT HA SETTINGS ***************
### If SSL enabled on RabbitMQ
#openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_use_ssl True
# openstack-config --set /etc/nova/nova.conf DEFAULT kombu_ssl_certfile /path/to/client.crt
# openstack-config --set /etc/nova/nova.conf DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key
### If Certs Signed by 3rd Party, also add this
#openstack-config --set /etc/nova/nova.conf DEFAULT kombu_ssl_ca_certs /path/to/ca.crt



# Updating compute for Neutron Networking
yum -y remove openstack-nova-network
openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_url http://${neutron_ip}:9696/
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_tenant_name services
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_username neutron
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_password ${neutron_pw}
openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_auth_url http://${keystone_ip}:35357/v2.0
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api neutron
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

  # Update L2 Agent - Open vSwitch
  openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_vif_driver nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
   ### NOTE - NOT CERTAIN IF THE ABOVE IS TRUE.  VALIDATE IN A FEW INSTALLS FIRST!

  # Update L2 Agent LinuxBridge
  openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_vif_driver nova.virt.libvirt.vif.LibvirtGenericVIFDriver
        # Ensure /etc/libvirt/qemu.conf has the following: 
        user = "root"
        group = "root"
        cgroup_device_acl = [
        "/dev/null", "/dev/full", "/dev/zero",
        "/dev/random", "/dev/urandom",
        "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
        "/dev/rtc", "/dev/hpet", "/dev/net/tun",
        ]

# On the compute host, configure iptables to allow VNC console access 
iptables -I INPUT -p tcp -m multiport --dports 5900:5999 -m comment --comment "nova compute vnc incoming" -j ACCEPT
service iptables save; service iptables restart

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


