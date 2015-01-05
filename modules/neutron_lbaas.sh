#!/bin/bash
##########################################################################
# Module:	neutron_lbaas
# Description:	Install Neutron Load Balancer as a Service
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

yum -y install neutron-lbaas-agent
yum -y install haproxy

# Configure LBaaS
openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT debug False
openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT device_driver neutron.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver
openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT use_namespaces True
openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT user_group haproxy

# Configure base Neutron 
### NEED WORK HERE.  But with ML2, it should have loadblanacer specified in service plugin and service provider similar to this: 
# [DEFAULT]
# service_plugins =neutron.services.loadbalancer.plugin.LoadBalancerPlugin,neutron.services.l3_router.l3_router_plugin.L3RouterPlugin,neutron.services.metering.metering_plugin.MeteringPlugin,neutron.services.firewall.fwaas_plugin.FirewallPlugin
# [service_providers]
# service_provider=LOADBALANCER:Haproxy:neutron.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default

# Start LBaaS 
systemctl enable neutron-lbaas-agent
systemctl start neutron-lbaas-agent
