#!/bin/bash
##########################################################################
# Module:	ceilometer
# Description:	Install Ceilometer Telemetry Service
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

yum -y install mongodb mongodb-server openstack-ceilometer-api openstack-ceilometer-central openstack-ceilometer-collector openstack-ceilometer-common openstack-ceilometer-alarm python-ceilometer python-ceilometerclient

# Create the Ceilometer records in keystone:
source ~/keystonerc_admin
keystone user-create --name=ceilometer --pass=${ceilometer_pw}
keystone role-create --name=ResellerAdmin
keystone user-role-add --user ceilometer --role ResellerAdmin --tenant services
--role ResellerAdmin
keystone user-role-add --user ceilometer --role admin --tenant services
keystone service-create --name=ceilometer --type=metering --description="OpenStack Telemetry Service"
keystone endpoint-create --service ceilometer --publicurl "${ceilometer_ip_public}:8777" --adminurl "${ceilometer_ip_admin}:8777" --internalurl "${ceilometer_ip_internal}:8777"
### region support??? 

# Configure Telemetry Service Auth 
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_host ${lkeystone_ip}
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_uri http://${keystone_ip}:5000/
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_user ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_password ${ceilometer_pw}
openstack-config --set /etc/ceilometer/ceilometer.conf publisher_rpc metering_secret ${ceilometer_metering_secret}

# Configure Ceilometer AMQP 
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rpc_backend ceilometer.openstack.common.rpc.impl_kombu
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_host ${amqp_ip}
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_port 5672
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_userid ${amqp_auth_user}
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_pass ${amqp_auth_pw}
  #*********** RABBIT HA SETTINGS ***************
  ### If SSL enabled on RabbitMQ
  #openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_use_ssl True
  #openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT kombu_ssl_certfile /path/to/client.crt
  #openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key
  ### If Certs Signed by 3rd Party, also add this
  #openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT kombu_ssl_ca_certs /path/to/ca.crt



# Create Telemetry Service Endpoints
openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT os_auth_url http://${keystone_ip}:35357/v2.0
openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT os_username ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT os_tenant_name services
openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT os_password ${ceilometer_pw}

# Configure Telemetry DB Connection 
openstack-config --set /etc/ceilometer/ceilometer.conf database connection mongodb://localhost:27017/ceilometer

# Start MongoDB ---> Validate the echo command!
echo '"OPTIONS="--smallfiles /etc/mongodb.conf' >> /etc/sysconfig/mongod
systemctl enable mongod
systemctl start mongod

# Configure monitored for glance, cinder, swift
yum -y install python-ceilometer python-ceilometerclient
### Glance 
openstack-config --set /etc/glance/glance-api.conf DEFAULT notifier_strategy rabbit
#openstack-config --set /etc/glance/glance-api.conf DEFAULT notifier_strategy qpid
### Cinder
openstack-config --set /etc/cinder/cinder.conf DEFAULT notification_driver cinder.openstack.common.notifier.rpc_notifier
openstack-config --set /etc/cinder/cinder.conf DEFAULT rpc_backend cinder.openstack.common.rpc.impl_qpid
openstack-config --set /etc/cinder/cinder.conf DEFAULT control_exchange cinder
### Swift 
  # Add this to /etc/swift/proxy-server.conf
[filter:ceilometer]
use = egg:ceilometer#swift
  # Add ceilometer to the pipeline in the same file
[pipeline:main]
pipeline = healthcheck cache authtoken keystoneauth proxy-server ceilometer
### Neutron -> Probably need to install the python ceilomter packages on all too
openstack-config --set /etc/neutron/neutron.conf \
DEFAULT notification_driver neutron.openstack.common.notifier.rpc_notifier
   ## Does neutron have a telemetry agent??  I thought it did now ... 

# Start and Enable Ceilometer Services
systemctl enable openstack-ceilometer-central
systemctl enable openstack-ceilometer-collector
systemctl enable openstack-ceilometer-api
systemctl enable openstack-ceilometer-alarm-evaluator
systemctl enable openstack-ceilometer-alarm-notifier
systemctl start openstack-ceilometer-central
systemctl start openstack-ceilometer-collector
systemctl start openstack-ceilometer-api
systemctl start openstack-ceilometer-alarm-evaluator
systemctl start openstack-ceilometer-alarm-notifier

