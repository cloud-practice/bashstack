#!/bin/bash
##########################################################################
# Module:	keystone_step3
# Description:	This configs endpoint, service, etc after install/activation
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# Create the identity service endpoint
export SERVICE_TOKEN=`cat ~/ks_admin_token`
export SERVICE_ENDPOINT="http://${keystone_ip_admin}:35357/v2.0"

keystone service-create --name=keystone --type=identity --description="Keystone Identity service"

keystone endpoint-create --service keystone --publicurl "http://${keystone_ip_public}:5000/v2.0" --adminurl "http://${keystone_ip_admin}:35357/v2.0" --internalurl "http://${keystone_ip_internal}:5000/v2.0"

## IS MULTI-REGION A REQUIREMENT?
##keystone endpoint-create --region REGION --service keystone --publicurl 'http://IP:5000/v2.0' --adminurl 'http://IP:35357/v2.0' --internalurl 'http://IP:5000/v2.0'

# Create an administrator accoount
keystone user-create --name admin --pass ${admin_pw}
keystone role-create --name admin
keystone tenant-create --name admin
keystone user-role-add --user admin --role admin --tenant admin

# Create member role, but not adding any members now... 
keysteon role-create _member_

# Create a regular user account 
# source /root/keystonerc_admin
#keystone user-create --name USER --pass PASSWORD
#keystone role-create --name Member
#keystone tenant-create --name TENANT
#keystone user-role-add --user USER --role Member --tenant TENANT
#
#cat << EOF >> /root/keystonerc_user
#export OS_USERNAME=USER
#export OS_TENANT_NAME=TENANT
#export OS_PASSWORD=PASSWORD
#export OS_AUTH_URL=http://${keystone_ip}:5000/v2.0/
#export PS1='[\u@\h \W(keystone_user)]\$ '
#EOF

# Create the services tenant
unset SERVICE_ENDPOINT
unset SERVICE_TOKEN
source ~/keystonerc_admin
keystone tenant-create --name services --description "Services Tenant"


# Validate
openstack-status | grep keystone
source ~/keystonerc_admin
keystone user-list
keystone token-get
#source ~/keystonerc_user
#keystone user-list
#keystone token-get

