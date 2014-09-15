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

# Configure the Glance DB Connection
openstack-config --set /etc/glance/glance-api.conf DEFAULT sql_connection mysql://glance:${glance_db_pw}@${mariadb_ip}/glance
openstack-config --set /etc/glance/glance-registry.conf DEFAULT sql_connection mysql://glance:${glance_db_pw}@${mariadb_ip}/glance

# Configure Image Service auth thru Keystone
  ### glance-api ###
openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_host ${keystone_ip}
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://${keystone_ip}:5000/
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_user glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_password ${glance_pw}

  ### glance-registry ###
openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_host ${keystone_ip}
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://${keystone_ip}:5000/
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_user glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_password ${glance_pw}

# Configure RabbitMQ Settings
openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_host ${amqp_ip}
openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_port 5672
openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_userid ${amqp_auth_user}
openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_pass ${amqp_auth_pw}
#*********** RABBIT HA SETTINGS ***************
### If SSL enabled on RabbitMQ
#openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_use_ssl True
#openstack-config --set /etc/glance/glance-api.conf DEFAULT kombu_ssl_certfile /path/to/client.crt
#openstack-config --set /etc/glance/glance-api.conf DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key
### If Certs Signed by 3rd Party, also add this
#openstack-config --set /etc/glance/glance-api.conf DEFAULT kombu_ssl_ca_certs /path/to/ca.crt




# --- Option: --- Using Swift Object Storage for Glance
###openstack-config --set /etc/glance/glance-api.conf DEFAULT default_store swift
###openstack-config --set /etc/glance/glance-api.conf DEFAULT swift_store_auth_address http://${keystone_ip}:5000/v2.0/
###openstack-config --set /etc/glance/glance-api.conf DEFAULT swift_store_create_container_on_put True
###openstack-config --set /etc/glance/glance-api.conf DEFAULT swift_store_key ${swift_store_key}
######################NEED TO CHECK WHERE THE SWIFT STORE KEY COMES FROM
# Set bind host / port
openstack-config --set /etc/glance/glance-api.conf DEFAULT bind_host 0.0.0.0
openstack-config --set /etc/glance/glance-api.conf DEFAULT bind_port 9292

# Config glance-api options 
openstack-config --set /etc/glance/glance-api.conf DEFAULT verbose True
openstack-config --set /etc/glance/glance-api.conf DEFAULT debug False
openstack-config --set /etc/glance/glance-api.conf DEFAULT default_store file
openstack-config --set /etc/glance/glance-api.conf DEFAULT log_file /var/log/glance/api.log
openstack-config --set /etc/glance/glance-api.conf DEFAULT backlog 4096
openstack-config --set /etc/glance/glance-api.conf DEFAULT workers 4
openstack-config --set /etc/glance/glance-api.conf DEFAULT show_image_direct_url False
openstack-config --set /etc/glance/glance-api.conf DEFAULT use_syslog False
openstack-config --set /etc/glance/glance-api.conf DEFAULT registry_host 0.0.0.0
openstack-config --set /etc/glance/glance-api.conf DEFAULT registry_port 9191
openstack-config --set /etc/glance/glance-api.conf DEFAULT notification_driver messaging
openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_notification_exchange glance
openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_notification_topic notifications
openstack-config --set /etc/glance/glance-api.conf DEFAULT kombu_ssl_version SSLv3
openstack-config --set /etc/glance/glance-api.conf DEFAULT log_dir /var/log/glance

# Config glance-cache options
openstack-config --set /etc/glance/glance-cache.conf DEFAULT verbose True
openstack-config --set /etc/glance/glance-cache.conf DEFAULT debug False
openstack-config --set /etc/glance/glance-cache.conf DEFAULT registry_host 0.0.0.0
openstack-config --set /etc/glance/glance-cache.conf DEFAULT registry_port 9191
openstack-config --set /etc/glance/glance-cache.conf DEFAULT auth_url http://localhost:5000/v2.0
openstack-config --set /etc/glance/glance-cache.conf DEFAULT admin_tenant_name services
openstack-config --set /etc/glance/glance-cache.conf DEFAULT admin_user glance
openstack-config --set /etc/glance/glance-cache.conf DEFAULT admin_password ${glance_pw}
openstack-config --set /etc/glance/glance-cache.conf DEFAULT filesystem_store_datadir /var/lib/glance/images/

# Config glance-registry options 
openstack-config --set /etc/glance/glance-registry.conf DEFAULT verbose True
openstack-config --set /etc/glance/glance-registry.conf DEFAULT debug False
openstack-config --set /etc/glance/glance-registry.conf DEFAULT bind_host 0.0.0.0
openstack-config --set /etc/glance/glance-registry.conf DEFAULT bind_port 9191
openstack-config --set /etc/glance/glance-registry.conf DEFAULT log_file /var/log/glance/registry.log
openstack-config --set /etc/glance/glance-registry.conf DEFAULT use_syslog False
openstack-config --set /etc/glance/glance-registry.conf DEFAULT sql_idle_timeout 3600
openstack-config --set /etc/glance/glance-registry.conf DEFAULT log_dir /var/log/glance

# Change ownership on /etc/glance
chown glance:root /etc/glance
chmod 770 /etc/glance

# Create Glance file backed directories 
mkdir -p /var/lib/glance/images
chown glance:glance /var/lib/glance/images


# Configure firewall to allow Glance traffic
iptables -I INPUT -p tcp -m multiport --dports 9292 -m comment --comment "glance incoming" -j ACCEPT
service iptables save; service iptables restart

# Configuring Glance to use SSL
#openstack-config --set /etc/glance/glance-api.conf DEFAULT cert_file PATH
#openstack-config --set /etc/glance/glance-api.conf DEFAULT key_file PATH
#openstack-config --set /etc/glance/glance-api.conf DEFAULT ca_file PATH

# Populate the Image Service Database
su glance -s /bin/sh -c "glance-manage db_sync"

# --- Option --- Configure glance to use a gluster mount point 
##yum -y install glusterfs glusterfs-fuse
  # ensure "glusterfs=nova.virt.libvirt.volume.LibvirtGlusterfsVolumeDriver" in libvirt_volume_drivers in /etc/nova/nova.conf
##openstack-config --set /etc/nova/nova-conf DEFAULT glusterfs_mount_point_base GLUSTER_MOUNT
##systemctl restart openstack-nova-compute
###### NOTE I LEFT OUT A BIG SECTION HERE ON CONFIGURING GLANCE AS A FILE SYSTEM
###### VS USING HTTP

# Start and enable glance services 
### I guess we don't want to enable if doing HA...
systemctl enable openstack-glance-registry
systemctl enable openstack-glance-api
systemctl start openstack-glance-registry
systemctl start openstack-glance-api

# Validate Glance 
mkdir /tmp/images
cd /tmp/images
#####wget cirros???
source ~/keystonerc_admin
### Note - we probably want to be able to handle disconnected (vs access to internet) - we might want to test RHEL images as well...
glance image-create --name "cirros-0.3.2-x86_64" --disk-format qcow2 --container-format bare --location http://download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img --is-public true

glance image-list
glance image-show cirros-0.3.2-x86_64

