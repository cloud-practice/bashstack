#!/bin/bash
##########################################################################
# Module:	nova_controller
# Description:	Install Nova Controller Services
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# Setup VNC Proxy
yum -y install openstack-nova-novncproxy openstack-nova-console

# Configure firewall to allow VNC proxy traffic 
iptables -I INPUT -p tcp -m multiport --dports 6080 -m comment --comment "nova novncproxy incoming" -j ACCEPT
service iptables save; service iptables restart

# Configure the VNC Proxy
openstack-config --set /etc/nova/nova.conf DEFAULT vnc_enabled true
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $(hostname -i)
openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://$(hostname -i):6080/vnc_auto.html
openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_port 6080

# Start consoleauth and novnc services
systemctl enable openstack-nova-consoleauth
systemctl enable openstack-nova-consoleauth
systemctl start openstack-nova-novncproxy
systemctl start openstack-nova-novncproxy


# Create the nova database
if [ ! -f /root/.my.cnf ] ; then    # Need password-less mysql access
  echo "ERROR - /root/.my.cnf doesn't exist" 
  exit 1
fi
mysql -u root << EOF
CREATE DATABASE nova;
GRANT ALL ON nova.* TO 'nova'@'%' IDENTIFIED BY '${nova_db_pw}';
GRANT ALL ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '${nova_db_pw}';
FLUSH PRIVILEGES;
quit
EOF

# Configure compute service authentication through keystone
source ~/keystonerc_admin
keystone user-create --name compute --pass ${nova_pw}
keystone user-role-add --user compute --role admin --tenant services
keystone service-create --name compute --type compute --description "OpenStack Compute Service"
keystone endpoint-create --service compute --publicurl "http://${nova_public_ip}:8774/v2/\$(tenant_id)s" --adminurl "http://${nova_admin_ip}:8774/v2/\$(tenant_id)s" --internalurl "http://${nova_internal_ip}:8774/v2/\$(tenant_id)s"

# Install compute service packages (controller)
yum -y install openstack-nova-api openstack-nova-conductor openstack-nova-scheduler

# Enable Nova to use SSL
#openstack-config --set /etc/nova/nova.conf DEFAULT enabled_ssl_apis LISTOFAPIS?
#openstack-config --set /etc/nova/nova.conf DEFAULT ssl_ca_file CAFILE
#openstack-config --set /etc/nova/nova.conf DEFAULT ssl_cert_file CERTFILE
#openstack-config --set /etc/nova/nova.conf DEFAULT ssl_key_file SSLPRIVATEKEY
#openstack-config --set /etc/nova/nova.conf DEFAULT tcp_keepidle 600

# Config compute authentication
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host ${keystone_ip}
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://${keystone_ip}:5000/
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password ${nova_pw}
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name services

# Configure nova database connection
openstack-config --set /etc/nova/nova.conf DEFAULT sql_connection mysql://nova:${nova_db_pw}@${mariadb_ip}/nova

# Config RabbitMQ Message Broker for Nova 
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend nova.openstack.common.rpc.impl_kombu
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_host ${amqp_ip}
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_port 5672
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_userid ${amqp_auth_user}
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_pass ${amqp_auth_pw}
#*********** RABBIT HA SETTINGS ***************
### If SSL enabled on RabbitMQ
#openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_use_ssl True
# openstack-config --set /etc/nova/nova.conf DEFAULT kombu_ssl_certfile /path/to/client.crt
# openstack-config --set /etc/nova/nova.conf DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key
### If Certs Signed by 3rd Party, also add this
#openstack-config --set /etc/nova/nova.conf DEFAULT kombu_ssl_ca_certs /path/to/ca.crt

systemctl enable openstack-nova-api
systemctl start openstack-nova-api
systemctl enable openstack-nova-scheduler
systemctl start openstack-nova-scheduler
systemctl enable openstack-nova-conductor
systemctl start openstack-nova-conductor


# -optional- X509 Cert System - required for EC2 API to compute services
#systemctl enable openstack-nova-cert
#systemctl start openstack-nova-cert

# -optional-  nova networking
#systemctl enable openstack-nova-network
#systemctl start openstack-nova-network


