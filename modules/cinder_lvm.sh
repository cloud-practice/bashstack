#!/bin/bash
##########################################################################
# Module:       cinder_lvm
# Description:  Install Cinder LVM Block Storage Services
##########################################################################

exit 1 
# This is not yet tested!

# Volume Service - LVM Backend (Block Storage Node)
yum -y install openstack-cinder
##### Create /etc/cinder/cinder.conf as above...  Or copy over... your choice
pvcreate /dev/sdXX
vgcreate cinder-volumes /dev/sdXX
openstack-config --set /etc/cinder/cinder.conf DEFAULT volume_group cinder-volumes
openstack-config --set /etc/cinder/cinder.conf DEFAULT volume_driver cinder.volume.drivers.lvm.LVMISCSIDriver

# Setup iSCSI Target (iSCSI Server)
yum -y install targetcli
systemctl enable target
systemctl start target
##### NOTE - This is tgtd on RHEL 6

