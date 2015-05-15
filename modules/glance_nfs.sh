#!/bin/bash
##########################################################################
# Module:	glance_nfs
# Description:	Configure Glance for NFS backend
##########################################################################
ANSWERS=/root/bashstack/answers.txt

# TODO: Implement this section! 

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# Install nfs utils 
yum -y install nfs-utils

if [[ $ha == "y" ]] && [[ $ha_type == "keepalived" ]] ; then
  # Mount NFS file system via fstab if it doesn't already exist
  if [[ $(cat /etc/fstab | grep "/var/lib/glance" | wc -l) -eq 0 ]]; then
    echo "$glance_backend_nfs_mount /var/lib/glance nfs _netdev 0 0" >> /etc/fstab
    mount -a
    chown glance:nobody /var/lib/glance
  fi
fi

