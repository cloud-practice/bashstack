#!/bin/bash
##########################################################################
# Module:	keystone
# Description:	Install Keystone Identity Service
##########################################################################
ANSWERS=/root/bashstack/answers.txt

# TODO: cron job to clean up expired tokens
# TODO: Update for keystone httpd setup - example at https://github.com/beekhof/osp-ha-deploy/blob/master/keepalived/keystone-config.md

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

yum install -y openstack-keystone openstack-utils openstack-selinux

# Firewall rules for keystone
if [[ $(systemctl is-active firewalld) == "active" ]] ; then
  firewall-cmd --add-port=5000/tcp
  firewall-cmd --add-port=5000/tcp --permanent
  firewall-cmd --add-port=35357/tcp
  firewall-cmd --add-port=35357/tcp --permanent
elif  [[ $(systemctl is-active iptables) == "active" ]] ; then
iptables -I INPUT -p tcp -m multiport --dports 5000,35357 -m comment --comment "keystone incoming" -j ACCEPT
  service iptables save; service iptables restart
else
  echo "No firewall rules created as firewalld and iptables are inactive"
fi



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
openstack-config --set /etc/keystone/keystone.conf database max_retries -1


### SSL Setup?
#openstack-config --set /etc/keystone/keystone.conf signing certfile /etc/keystone/ssl/certs/signing_cert.pem
#openstack-config --set /etc/keystone/keystone.conf signing keyfile /etc/keystone/ssl/private/signing_key.pem
#openstack-config --set /etc/keystone/keystone.conf signing ca_certs /etc/keystone/ssl/certs/ca.pem
#openstack-config --set /etc/keystone/keystone.conf signing key_size 1024
#openstack-config --set /etc/keystone/keystone.conf signing valid_days 3650
#openstack-config --set /etc/keystone/keystone.conf signing ca_password None

# Configure RabbitMQ Settings
openstack-config --set /etc/keystone/keystone.conf DEFAULT rpc_backend keystone.openstack.common.rpc.impl_kombu
if [[ $ha == y ]]; then
  rabbit_nodes_cs=$(sed -e 's/ /,/g' ${rabbit_nodes})
  openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_hosts ${rabbit_nodes}
  openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_ha_queues True
else
  openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_host ${amqp_ip}
  openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_ha_queues False
fi
openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_port 5672
openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_userid ${amqp_auth_user}
openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_pass ${amqp_auth_pw}
#*********** RABBIT SSL SETTINGS ***************
### If SSL enabled on RabbitMQ
#openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_use_ssl True
#openstack-config --set /etc/keystone/keystone.conf DEFAULT kombu_ssl_certfile /path/to/client.crt
#openstack-config --set /etc/keystone/keystone.conf DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key
### If Certs Signed by 3rd Party, also add this
#openstack-config --set /etc/keystone/keystone.conf DEFAULT kombu_ssl_ca_certs /path/to/ca.crt

# Set Keystone bind ports / hosts (etc)
openstack-config --set /etc/keystone/keystone.conf DEFAULT public_bind_host $(ip addr show dev ${keystone_public_bind_nic} scope global | grep dynamic| sed -e 's#.*inet ##g' -e 's#/.*##g')
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_bind_host $(ip addr show dev ${keystone_admin_bind_nic} scope global | grep dynamic| sed -e 's#.*inet ##g' -e 's#/.*##g')
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_endpoint 'http://${keystone_ip}:35357/'
openstack-config --set /etc/keystone/keystone.conf DEFAULT public_endpoint 'http://${keystone_ip}:5000/'
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

