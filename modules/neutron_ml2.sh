#!/bin/bash
##########################################################################
# Module:	neutron_ml2
# Description:	Install Neutron ML2 plugin
##########################################################################

yum -y install openstack-neutron-ml2
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
vi /etc/neutron/plugins/ml2/ml2_conf.ini --- Add appropriate config (nice)
[ml2]
type_drivers = local,flat,vlan,gre,vxlan
mechanism_drivers = openvswitch,linuxbridge,l2population
[agent]
l2_population = True

  # Enable the ML2 plugin and L3 router
  openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin neutron.plugins.ml2.plugin.Ml2Plugin
  openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins = neutron.services.l3_router.l3_router_plugin.L3RouterPlugin
   ##### NOTE - Service plugins also needs to include things like FWaaS.  
   #### Might need more thought about it...

   ### Note - a bit later on we create the neutron ml2 database but it's needed before: 
   systemctl restart neutron-server

