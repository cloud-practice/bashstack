#!/bin/bash
##########################################################################
# Module:	glance
# Description:	Install Glance Image Service
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

yum -y install openstack-glance openstack-utils openstack-selinux

# Create the Image Service Database
if [ ! -f /root/.my.cnf ] ; then    # Need password-less mysql access
  echo "ERROR - /root/.my.cnf doesn't exist" 
  exit 1
fi
mysql -u root << EOF
CREATE DATABASE glance;
GRANT ALL ON glance.* TO 'glance'@'%' IDENTIFIED BY '${glance_db_pw}';
GRANT ALL ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '${glance_db_pw}';
FLUSH PRIVILEGES;
quit
EOF

# Configure Glance to authenticate with Keystone
source ~/keystonerc_admin
keystone user-create --name glance --pass ${glance_pw}
keystone user-role-add --user glance --role admin --tenant services
keystone service-create --name glance --type image --description "Glance Image Service"

keystone endpoint-create --service glance --publicurl "http://${glance_ip_public}:9292" --adminurl "http://${glance_ip_admin}:9292" --internalurl "http://${glance_ip_internal}:9292"
## Add support for regions? 

# Setup Glance Firewall Configuration
if [[ $(systemctl is-active firewalld) == "active" ]] ; then
  firewall-cmd --add-port=9191/tcp
  firewall-cmd --add-port=9191/tcp --permanent
  firewall-cmd --add-port=9292/tcp
  firewall-cmd --add-port=9292/tcp --permanent
elif  [[ $(systemctl is-active iptables) == "active" ]] ; then
  iptables -I INPUT -p tcp -m multiport --dports 9191 -m comment --comment "glance registry incoming" -j ACCEPT
  iptables -I INPUT -p tcp -m multiport --dports 9292 -m comment --comment "glance API incoming" -j ACCEPT
service iptables save; service iptables restart
fi 

# Configure the API Service
openstack-config --set /etc/glance/glance-api.conf database connection mysql://glance:${glance_db_pw}@${mariadb_ip}/glance
openstack-config --set /etc/glance/glance-api.conf database max_retries -1

openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_host ${keystone_ip}
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_protocol http
#openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://${keystone_ip}:5000/
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_user glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_password ${glance_pw}
openstack-config --set /etc/glance/glance-api.conf DEFAULT notification_driver messaging
openstack-config --set /etc/glance/glance-api.conf DEFAULT registry_host ${glance_ip}
openstack-config --set /etc/glance/glance-api.conf DEFAULT bind_host $(ip addr show dev ${glance_bind_nic} scope global | grep dynamic| sed -e 's#.*inet ##g' -e 's#/.*##g')
#openstack-config --set /etc/glance/glance-api.conf DEFAULT registry_port 9191

#openstack-config --set /etc/glance/glance-api.conf DEFAULT verbose True
#openstack-config --set /etc/glance/glance-api.conf DEFAULT debug False
#openstack-config --set /etc/glance/glance-api.conf DEFAULT default_store file
#openstack-config --set /etc/glance/glance-api.conf DEFAULT log_file /var/log/glance/api.log
#openstack-config --set /etc/glance/glance-api.conf DEFAULT backlog 4096
#openstack-config --set /etc/glance/glance-api.conf DEFAULT workers 4
#openstack-config --set /etc/glance/glance-api.conf DEFAULT show_image_direct_url False
#openstack-config --set /etc/glance/glance-api.conf DEFAULT use_syslog False
#openstack-config --set /etc/glance/glance-api.conf DEFAULT registry_host 0.0.0.0
#openstack-config --set /etc/glance/glance-api.conf DEFAULT registry_port 9191
#openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_notification_exchange glance
#openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_notification_topic notifications
#openstack-config --set /etc/glance/glance-api.conf DEFAULT kombu_ssl_version SSLv3
#openstack-config --set /etc/glance/glance-api.conf DEFAULT log_dir /var/log/glance




# Configure the Registry Service
openstack-config --set /etc/glance/glance-registry.conf database connection mysql://glance:${glance_db_pw}@${mariadb_ip}/glance
openstack-config --set /etc/glance/glance-registry.conf database max_retries -1

openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_host ${keystone_ip}
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_protocol http
#openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://${keystone_ip}:5000/
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_user glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_password ${glance_pw}
#openstack-config --set /etc/glance/glance-registry.conf DEFAULT verbose True
#openstack-config --set /etc/glance/glance-registry.conf DEFAULT debug False
openstack-config --set /etc/glance/glance-registry.conf DEFAULT bind_host $(ip addr show dev ${glance_bind_nic} scope global | grep dynamic| sed -e 's#.*inet ##g' -e 's#/.*##g')
#openstack-config --set /etc/glance/glance-registry.conf DEFAULT bind_port 9191
#openstack-config --set /etc/glance/glance-registry.conf DEFAULT log_file /var/log/glance/registry.log
#openstack-config --set /etc/glance/glance-registry.conf DEFAULT use_syslog False
#openstack-config --set /etc/glance/glance-registry.conf DEFAULT sql_idle_timeout 3600
#openstack-config --set /etc/glance/glance-registry.conf DEFAULT log_dir /var/log/glance



# Configure RabbitMQ Settings
if [[ $ha == y ]]; then
  rabbit_nodes_cs=$(sed -e 's/ /,/g' ${rabbit_nodes})
  openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_hosts ${rabbit_nodes_cs}
  openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_ha_queues True
else
  openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_host ${amqp_ip}
  openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_ha_queues False
fi
openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_port 5672
openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_userid ${amqp_auth_user}
openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_pass ${amqp_auth_pw}
#*********** RABBIT SSL SETTINGS ***************
### If SSL enabled on RabbitMQ
#openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_use_ssl True
#openstack-config --set /etc/glance/glance-api.conf DEFAULT kombu_ssl_certfile /path/to/client.crt
#openstack-config --set /etc/glance/glance-api.conf DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key
### If Certs Signed by 3rd Party, also add this
#openstack-config --set /etc/glance/glance-api.conf DEFAULT kombu_ssl_ca_certs /path/to/ca.crt

# Change ownership on /etc/glance
chown glance:root /etc/glance
chmod 770 /etc/glance

# Populate the Image Service Database
if [[ $(hostname -s) == $glance_bootstrap_node ]]; then
  su glance -s /bin/sh -c "glance-manage db_sync"
fi 

# Run the appropriate glance backend

case $glance_backend in 
  "file" )
      glance_file.sh ;;
  "ceph" )
      glance_ceph.sh ;;
  "gluster" )
      glance_gluster.sh ;;
  "nfs" )
      glance_nfs.sh ;;
  "swift" )
      glance_swift.sh ;;
  * )
      echo "No backend recognized.  Exiting"
      exit 1 ;; 
esac
