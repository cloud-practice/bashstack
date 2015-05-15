#!/bin/bash
##########################################################################
# Module:	glance_test.sh
# Description:	Validate Glance Image Service
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

mkdir /tmp/images
cd /tmp/images
#####wget cirros???
source ~/keystonerc_admin
### Note - we probably want to be able to handle disconnected (vs access to internet) - we might want to test RHEL images as well...
glance image-create --name "cirros-0.3.2-x86_64" --disk-format qcow2 --container-format bare --location http://download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img --is-public true

glance image-list
glance image-show cirros-0.3.2-x86_64

