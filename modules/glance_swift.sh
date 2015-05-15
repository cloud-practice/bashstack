#!/bin/bash
##########################################################################
# Module:	glance_swift
# Description:	Configure glance for swift backend
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi
  exit 1
fi

# Using Swift Object Storage for Glance
###openstack-config --set /etc/glance/glance-api.conf DEFAULT default_store swift
###openstack-config --set /etc/glance/glance-api.conf DEFAULT swift_store_auth_address http://${keystone_ip}:5000/v2.0/
###openstack-config --set /etc/glance/glance-api.conf DEFAULT swift_store_create_container_on_put True
###openstack-config --set /etc/glance/glance-api.conf DEFAULT swift_store_key ${swift_store_key}
######################NEED TO CHECK WHERE THE SWIFT STORE KEY COMES FROM

