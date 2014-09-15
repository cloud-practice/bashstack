#!/bin/bash
##########################################################################
# Module:	ceilometer_compute
# Description:	Install Ceilometer Agent on Compute Hosts
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi


# Configure monitored compute Node(s)
yum -y install openstack-ceilometer-compute python-ceilometer python-ceilometerclient
openstack-config --set /etc/nova/nova.conf DEFAULT instance_usage_audit True
DEFAULT instance_usage_audit True
openstack-config --set /etc/nova/nova.conf DEFAULT instance_usage_audit_period hour
openstack-config --set /etc/nova/nova.conf DEFAULT notify_on_state_change vm_and_task_state
openstack-config --set /etc/nova/nova.conf DEFAULT notification_driver nova.openstack.common.notifier.rpc_notifier
### NOTE THIS LOOKS LIKE AN ERROR.  WE WILL NEED 2 SET.  I DON'T THINK
### openstack-config can do this...
openstack-config --set /etc/nova/nova.conf DEFAULT notification_driver ceilometer.compute.nova_notifier

# And on the compute node
systemctl enable openstack-ceilometer-compute
systemctl start openstack-ceilometer-compute


