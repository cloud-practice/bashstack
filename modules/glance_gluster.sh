#!/bin/bash
##########################################################################
# Module:	glance_gluster
# Description:	Configure Glance for gluster backend
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# --- Option --- Configure glance to use a gluster mount point 
##yum -y install glusterfs glusterfs-fuse
  # ensure "glusterfs=nova.virt.libvirt.volume.LibvirtGlusterfsVolumeDriver" in libvirt_volume_drivers in /etc/nova/nova.conf
##openstack-config --set /etc/nova/nova-conf DEFAULT glusterfs_mount_point_base GLUSTER_MOUNT
##systemctl restart openstack-nova-compute

### Make certain to create glance-fs-clone here if pacemaker ??  I'm thinking that's not needed...

