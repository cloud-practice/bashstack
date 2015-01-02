#!/bin/bash
##########################################################################
# Module:	trove
# Description:	Install Trove Database Service
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# Install Packages 
yum -y install openstack-trove python-troveclient

# Create the trove user to auth with keystone
. /root/keystonerc_admin
keystone user-create --name=trove --pass=${trove_pw}
keystone user-role-add --user=trove --tenant=services --role=admin

# Configure service URLs, logging, and database connection
for cfgfile in /etc/trove/trove.conf /etc/trove/trove-taskmanager.conf /etc/trove/trove-conductor.conf
do
  openstack-config --set $cfgfile DEFAULT log_dir /var/log/trove
  openstack-config --set $cfgfile DEFAULT trove_auth_url = http://${keystone_ip}:5000/v2.0
  openstack-config --set $cfgfile DEFAULT nova_compute_url = http://${nova_ip}:8774/v2
  openstack-config --set $cfgfile DEFAULT cinder_url = http://${cinder_ip}:8776/v1
  openstack-config --set $cfgfile DEFAULT swift_url = http://${swift_ip}:8080/v1/AUTH_
  openstack-config --set $cfgfile DEFAULT sql_connection = mysql://trove:${trove_db_pw}@${mariadb_ip}/trove
  openstack-config --set $cfgfile DEFAULT notifier_queue_hostname = controller
done

# Setup Qpid message broker
# openstack-config --set /etc/trove/trove-api.conf DEFAULT rpc_backend qpid
# openstack-config --set /etc/trove/trove-taskmaster.conf DEFAULT rpc_backend qpid
# openstack-config --set /etc/trove/trove-conductor.conf DEFAULT rpc_backend qpid
# openstack-config --set /etc/trove/trove-api.conf DEFAULT qpid_hostname controller
# openstack-config --set /etc/trove/trove-taskmaster.conf DEFAULT qpid_hostname controller
# openstack-config --set /etc/trove/trove-conductor.conf DEFAULT qpid_hostname controller

# Configure RabbitMQ Settings
for cfgfile in /etc/trove/trove.conf /etc/trove/trove-taskmanager.conf /etc/trove/trove-conductor.conf
do
  openstack-config --set $cfgfile DEFAULT rpc_backend trove.openstack.common.rpc.impl_kombu
  openstack-config --set $cfgfile DEFAULT rabbit_host ${amqp_ip}
  openstack-config --set $cfgfile DEFAULT rabbit_port 5672
  openstack-config --set $cfgfile DEFAULT rabbit_userid ${amqp_auth_user}
  openstack-config --set $cfgfile DEFAULT rabbit_pass ${amqp_auth_pw}
  #*********** RABBIT HA SETTINGS ***************
  ### If SSL enabled on RabbitMQ
  #openstack-config --set $cfgfile DEFAULT rabbit_use_ssl True
  #openstack-config --set $cfgfile DEFAULT kombu_ssl_certfile /path/to/client.crt
  #openstack-config --set $cfgfile DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key
  ### If Certs Signed by 3rd Party, also add this
  #openstack-config --set $cfgfile DEFAULT kombu_ssl_ca_certs /path/to/ca.crt
done

# Setup keystone authentication 
openstack-config --set /etc/trove/api-paste.conf filter:authtoken auth_host controller
openstack-config --set /etc/trove/api-paste.conf filter:authtoken auth_port 35357
openstack-config --set /etc/trove/api-paste.conf filter:authtoken auth_protocol http
openstack-config --set /etc/trove/api-paste.conf filter:authtoken admin_user trove
openstack-config --set /etc/trove/api-paste.conf filter:authtoken admin_password ADMIN_PASS
openstack-config --set /etc/trove/api-paste.conf filter:authtoken admin_token ADMIN_TOKEN
openstack-config --set /etc/trove/api-paste.conf filter:authtoken admin_tenant_name services
openstack-config --set /etc/trove/api-paste.conf filter:authtoken signing_dir /var/cache/trove

# Add Default datastore and network label regex to trove.conf
openstack-config --set /etc/trove/trove.conf DEFAULT default_datastore mysql
openstack-config --set /etc/trove/trove.conf DEFAULT add_addresses True
openstack-config --set /etc/trove/trove.conf DEFAULT network_label_regex ^NETWORK_LABEL$

# Add Nova Compute connection details for task manager
openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_user = admin
openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_pass = ADMIN_PASS
openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_tenant_name = services

# Prepare the trove database
if [ ! -f /root/.my.cnf ] ; then    # Need password-less mysql access
  echo "ERROR - /root/.my.cnf doesn't exist"
  exit 1
fi
mysql -u root  << EOF
CREATE DATABASE trove;
GRANT ALL PRIVILEGES ON trove.* TO trove@'localhost' IDENTIFIED BY '${trove_db_pw}';
GRANT ALL PRIVILEGES ON trove.* TO trove@'%' IDENTIFIED BY '${trove_db_pw}';
FLUSH PRIVILEGES;
quit
EOF

# Initialize the DB.  Create a datastore for each database type you want to use
su -s /bin/sh -c "trove-manage db_sync" trove
su -s /bin/sh -c "trove-manage datastore_update mysql ''" trove
su -s /bin/sh -c "trove-manage datastore_update mongodb ''" trove
su -s /bin/sh -c "trove-manage datastore_update cassandra ''" trove

### ***** NOTE - A glance image with the trove guest agent must be used!  
### Add these lines to the trove-guestagent.conf
   # On the image: 
   # yum -y install openstack-trove-guestagent
   ###openstack-config --set /etc/trove/trove-guestagent.conf rpc_backend = trove.openstack.common.rpc.impl_qpid
   ###qpid_host = controller
   # openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT rpc_backend trove.openstack.common.rpc.impl_kombu
   # openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_host ${amqp_ip}
   # openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_port 5672
   # openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_userid ${amqp_auth_user}
   # openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_pass ${amqp_auth_pw}
   #*********** RABBIT HA SETTINGS ***************
   ### If SSL enabled on RabbitMQ
   #openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_use_ssl True
   #openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT kombu_ssl_certfile /path/to/client.crt
   #openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key
   ### If Certs Signed by 3rd Party, also add this
   #openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT kombu_ssl_ca_certs /path/to/ca.crt
   # Add Nova Config to the Guest Agent
   #openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_user = admin
   #openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_pass = ADMIN_PASS
   #openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_tenant_name = services
   #openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT trove_auth_url = http://controller:35357/v2.0

# Update the datastore to use the new glance image
   ### Note this example is for mysql... 
trove-manage --config-file=/etc/trove/trove.conf datastore_version_update \
  mysql mysql-5.5 mysql glance_image_ID mysql-server-5.5 1

# Register trove with keystone
keystone service-create --name=trove --type=database --description="OpenStack Database Service"
keystone endpoint-create --service=trove --publicurl=http://${trove_ip_public}:8779/v1.0/%\(tenant_id\)s --internalurl=http://${trove_ip_internal}:8779/v1.0/%\(tenant_id\)s --adminurl=http://${trove_ip_admin}:8779/v1.0/%\(tenant_id\)s

# Enable and Start the Database Services
systemctl enable openstack-trove-api
systemctl enable openstack-trove-taskmanager
systemctl enable openstack-trove-conductor
systemctl start openstack-trove-api
systemctl start openstack-trove-taskmanager
systemctl start openstack-trove-conductor

# Verify the Trove Database Service Installation
. /root/keystonerc_admin
trove list
trove create name 2 --size=2 --databases=DBNAME --users USER:PASSWORD --datastore_version mysql-5.5 --datastore mysql


