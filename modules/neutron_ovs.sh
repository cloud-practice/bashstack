#!/bin/bash
##########################################################################
# Module:	neutron_ovs
# Description:	Install Neutron Open vSwitch Plugin
##########################################################################

### This monolithic plug-in has been deprecated
  # Use ML2 with Open vSwift Mechanism Driver 

  yum -y install openstack-neutron-openvswitch

  ln -s /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini /etc/neutron/plugin.ini

  # Set the tenant network type (flat, gre, local, vlan, or vxlan)
  openstack-config --set /etc/neutron/plugin.ini OVS tenant_network_type TYPE

  # If Flat or VLAN: (ie physnet1:1000:2999,physnet2:3000:3999)
  openstack-config --set /etc/neutron/plugin.ini OVS network_vlan_ranges NAME:START:END

  # Update the core plugin.  Probably also need the services plugin above
  openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2

