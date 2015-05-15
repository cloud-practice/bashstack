#!/bin/bash
##########################################################################
# Module:	keystone_test
# Description:	Validate Keystone Identity Service
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# Validate
openstack-status | grep keystone
source ~/keystonerc_admin
keystone user-list
keystone token-get
#source ~/keystonerc_user
#keystone user-list
#keystone token-get

