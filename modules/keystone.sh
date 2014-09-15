#!/bin/bash
##########################################################################
# Module:	keystone
# Description:	Install Keystone Identity Service
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

yum install -y openstack-keystone openstack-utils openstack-selinux
if [ ! -f /root/.my.cnf ] ; then    # Need password-less mysql access
  echo "ERROR - /root/.my.cnf doesn't exist" 
  exit 1
fi
mysql -u root << EOF
CREATE DATABASE keystone;
GRANT ALL ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '${keystone_db_pw}';
GRANT ALL ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '${keystone_db_pw}';
FLUSH PRIVILEGES;
quit
EOF

# Populate the keystone database
su keystone -s /bin/sh -c "keystone-manage db_sync"

# Set the identity service admin token
if [[ $keystone_admin_token == "" ]] ; then
  export SERVICE_TOKEN=$(openssl rand -hex 10)
else
  export SERVICE_TOKEN=$keystone_admin_token
fi
echo $SERVICE_TOKEN > ~/ks_admin_token
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $SERVICE_TOKEN


####
# Setup cron job to run this once per minute to clean up expired tokens
#keystone-manage token_flush

# Setup keystone database connection
openstack-config --set /etc/keystone/keystone.conf database connection mysql://keystone:${keystone_db_pw}@${mariadb_ip}/keystone
openstack-config --set /etc/keystone/keystone.conf database idle_timeout 200

# Configure PKI 
keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
chown -R keystone:keystone /var/log/keystone /etc/keystone/ssl/
chmod -R o-rwx /etc/keystone/ssl

#openstack-config --set /etc/keystone/keystone.conf signing token_format PKI
#openstack-config --set /etc/keystone/keystone.conf signing certfile /etc/keystone/ssl/certs/signing_cert.pem
#openstack-config --set /etc/keystone/keystone.conf signing keyfile /etc/keystone/ssl/private/signing_key.pem
#openstack-config --set /etc/keystone/keystone.conf signing ca_certs /etc/keystone/ssl/certs/ca.pem
#openstack-config --set /etc/keystone/keystone.conf signing key_size 1024
#openstack-config --set /etc/keystone/keystone.conf signing valid_days 3650
#openstack-config --set /etc/keystone/keystone.conf signing ca_password None

# Configure RabbitMQ Settings
openstack-config --set /etc/keystone/keystone.conf DEFAULT rpc_backend keystone.openstack.common.rpc.impl_kombu
openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_host ${amqp_ip}
openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_port 5672
openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_userid ${amqp_auth_user}
openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_pass ${amqp_auth_pw}
#*********** RABBIT HA SETTINGS ***************
### If SSL enabled on RabbitMQ
#openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_use_ssl True
#openstack-config --set /etc/keystone/keystone.conf DEFAULT kombu_ssl_certfile /path/to/client.crt
#openstack-config --set /etc/keystone/keystone.conf DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key
### If Certs Signed by 3rd Party, also add this
#openstack-config --set /etc/keystone/keystone.conf DEFAULT kombu_ssl_ca_certs /path/to/ca.crt

# Set Keystone bind ports / hosts (etc)
openstack-config --set /etc/keystone/keystone.conf DEFAULT public_bind_host 0.0.0.0
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_bind_host 0.0.0.0
openstack-config --set /etc/keystone/keystone.conf DEFAULT compute_port 8774
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_port 35357
openstack-config --set /etc/keystone/keystone.conf DEFAULT public_port 5000
openstack-config --set /etc/keystone/keystone.conf DEFAULT debug False
openstack-config --set /etc/keystone/keystone.conf DEFAULT verbose True
openstack-config --set /etc/keystone/keystone.conf DEFAULT log_dir /var/log/keystone
openstack-config --set /etc/keystone/keystone.conf DEFAULT use_syslog False

openstack-config --set /etc/keystone/keystone.conf catalog template_file /etc/keystone/default_catalog.templates
openstack-config --set /etc/keystone/keystone.conf catalog driver keystone.catalog.backends.sql.Catalog

openstack-config --set /etc/keystone/keystone.conf token expiration 3600
openstack-config --set /etc/keystone/keystone.conf token provider keystone.token.providers.pki.Provider
openstack-config --set /etc/keystone/keystone.conf token driver keystone.token.backends.sql.Token


# Configure Firewall to Allow Identity Service Traffic
iptables -I INPUT -p tcp -m multiport --dports 5000,35357 -m comment --comment "keystone incoming" -j ACCEPT
service iptables save; service iptables restart

# Start Keystone 
systemctl enable openstack-keystone
systemctl start openstack-keystone

# Create the identity service endpoint
export SERVICE_TOKEN=`cat ~/ks_admin_token`
export SERVICE_ENDPOINT="http://${keystone_ip_admin}:35357/v2.0"

keystone service-create --name=keystone --type=identity --description="Keystone Identity service"

keystone endpoint-create --service keystone --publicurl 'http://${keystone_ip_public}:5000/v2.0' --adminurl 'http://${keystone_ip_admin}:35357/v2.0' --internalurl 'http://${keystone_ip_internal}:5000/v2.0'

## IS MULTI-REGION A REQUIREMENT???
##keystone endpoint-create --region REGION --service keystone --publicurl 'http://IP:5000/v2.0' --adminurl 'http://IP:35357/v2.0' --internalurl 'http://IP:5000/v2.0'

# keystone endpoint-list

# Create an administrator accoount
export SERVICE_TOKEN=`cat ~/ks_admin_token`
export SERVICE_ENDPOINT="http://${keystone_ip_admin}:35357/v2.0"
keystone user-create --name admin --pass ${admin_pw}
keystone role-create --name admin
keystone tenant-create --name admin
keystone user-role-add --user admin --role admin --tenant admin

cat << EOF >> /root/keystonerc_admin
export OS_USERNAME=admin
export OS_TENANT_NAME=admin
export OS_PASSWORD=${admin_pw}
export OS_AUTH_URL=http://${keystone_ip}:5000/v2.0/
export PS1='[\u@\h \W(keystone_admin)]\$ '
EOF

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

