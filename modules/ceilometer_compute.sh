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
yum -y install openstack-ceilometer-compute python-ceilometer python-ceilometerclient python-pecan

openstack-config --set /etc/nova/nova.conf DEFAULT instance_usage_audit True
openstack-config --set /etc/nova/nova.conf DEFAULT instance_usage_audit_period hour
openstack-config --set /etc/nova/nova.conf DEFAULT notify_on_state_change vm_and_task_state
openstack-config --set /etc/nova/nova.conf DEFAULT notification_driver nova.openstack.common.notifier.rpc_notifier
sed  -i -e  's/nova.openstack.common.notifier.rpc_notifier/nova.openstack.common.notifier.rpc_notifier\nnotification_driver  = ceilometer.compute.nova_notifier/g' /etc/nova/nova.conf
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_host ${keystone_ip}
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_user ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_password ${ceilometer_pw}
# Configure memcache nodes
memcnodesarray=($memcache_nodes)
for memcnode in "${memcnodesarray[@]}"
do
  memcstring="${memcstring}${memcnode}:11211,"
done
memcache_nodes_final=$(echo $memcstring | sed 's/,$//')
openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT memcache_servers ${memcache_nodes_final}

# Configure Ceilometer AMQP 
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rpc_backend ceilometer.openstack.common.rpc.impl_kombu
if [[ $ha == y ]]; then
  rabbit_nodes_cs=$(sed -e 's/ /,/g' ${rabbit_nodes})
  openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_hosts ${rabbit_nodes_cs}
  openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_ha_queues True
else
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_host ${amqp_ip}
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_port 5672
  openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_ha_queues False
fi
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_userid ${amqp_auth_user}
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_pass ${amqp_auth_pw}

openstack-config --set /etc/ceilometer/ceilometer.conf publisher_rpc metering_secret ${ceilometer_metering_secret}
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_auth_url http://${keystone_ip}:5000/v2.0
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_username ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_tenant_name services
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_password ${ceilometer_pw}

if [[ $ha == "y" ]]; then
  # Configure memcache nodes
   mongonodesarray=($mongo_nodes)
   for mongonode in "${mongonodesarray[@]}"
   do
      mongostring="${mongostring}${mongonode},"
   done
   mongo_nodes_final=$(echo $mongostring | sed 's/,$//')

  openstack-config --set /etc/ceilometer/ceilometer.conf database connection mongodb://${mongo_nodes_final}:27017/ceilometer?replicaSet=ceilometer
else
  openstack-config --set /etc/ceilometer/ceilometer.conf database connection mongodb://${mongo_ip}:27017/ceilometer
fi

openstack-config --set /etc/ceilometer/ceilometer.conf database connection max_retries -1

# keep last 5 days data only (value is in secs)
openstack-config --set /etc/ceilometer/ceilometer.conf database time_to_live 432000

# Start & Enable Ceilometer-Compute
systemctl enable openstack-ceilometer-compute
systemctl start openstack-ceilometer-compute


