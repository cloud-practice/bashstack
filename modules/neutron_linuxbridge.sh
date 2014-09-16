#!/bin/bash
##########################################################################
# Module:	neutron_linuxbridge
# Description:	Install Neutron Linux Bridge L2 Plugin
##########################################################################

### This monolithic plug-in has been deprecated
  ### Use ML2 linuxbridge Mechanism Plugin

yum -y install openstack-neutron-linuxbridge
  ln -s /etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini /etc/neutron/plugin.ini

  # Set the tenant network type (flat, local, or vlan)
  openstack-config --set /etc/neutron/plugin.ini VLAN tenant_network_type TYPE

  # If Flat or VLAN: (ie physnet1:1000:2999,physnet2:3000:3999)
  openstack-config --set /etc/neutron/plugin.ini LINUX_BRIDGE network_vlan_ranges NAME:START:END

  # Update the core plugin.  Probably also need the services plugin above
  openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin neutron.plugins.linuxbridge.lb_neutron_plugin.LinuxBridgePluginV2


