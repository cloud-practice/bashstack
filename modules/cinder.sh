#!/bin/bash
##########################################################################
# Module:	cinder
# Description:	Install Cinder Block Storage Service
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# Create Cinder Database
if [ ! -f /root/.my.cnf ] ; then    # Need password-less mysql access
  echo "ERROR - /root/.my.cnf doesn't exist" 
  exit 1
fi
mysql -u root << EOF
CREATE DATABASE cinder;
GRANT ALL ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '${cinder_db_pw}';
GRANT ALL ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '${cinder_db_pw}';
FLUSH PRIVILEGES;
quit
EOF

# Create Cinder Block Storage Service Identity Records
source ~/keystonerc_admin
keystone user-create --name cinder --pass ${cinder_pw}
keystone user-role-add --user cinder --role admin --tenant services
keystone service-create --name cinder --type volume --description "Cinder Volume Service"
keystone endpoint-create --service cinder --publicurl "http://${cinder_ip_public}:8776/v1/\$(tenant_id)s" --adminurl "http://${cinder_ip_admin}:8776/v1/\$(tenant_id)s" --internalurl "http://${cinder_ip_internal}:8776/v1/\$(tenant_id)s"

# Install Cinder Packages
yum install -y openstack-cinder openstack-utils openstack-selinux

# Configure Block Storage Authentication through keystone
openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken auth_host ${keystone_ip}
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken service_port 5000
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken service_host ${keystone_ip}
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken service_protocol http
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken auth_uri http://${keystone_ip}:5000/
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken auth_port 35357
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken admin_tenant_name services
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken admin_user cinder
openstack-config --set /etc/cinder/api-paste.ini filter:authtoken admin_password ${cinder_pw}

# Configure Cinder to Use SSL
# openstack-config --set /etc/cinder/cinder.conf ssl backlog REQS
# openstack-config --set /etc/cinder/cinder.conf ssl tcp_keepidle SECS
# openstack-config --set /etc/cinder/cinder.conf ssl ssl_ca_file CAFILE
# openstack-config --set /etc/cinder/cinder.conf ssl ssl_cert_file CERTFILE
# openstack-config --set /etc/cinder/cinder.conf ssl ssl_key_file KEYFILE

# Configure RabbitMQ Settings
openstack-config --set /etc/cinder/cinder.conf DEFAULT rpc_backend cinder.openstack.common.rpc.impl_kombu
openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_host ${amqp_ip}
openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_port 5672
openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_userid ${amqp_auth_user}
openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_password ${amqp_auth_pw}
#*********** RABBIT HA SETTINGS ***************
### If SSL enabled on RabbitMQ
#openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_use_ssl True
#openstack-config --set /etc/cinder/cinder.conf DEFAULT kombu_ssl_certfile /path/to/client.crt
#openstack-config --set /etc/cinder/cinder.conf DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key
### If Certs Signed by 3rd Party, also add this
#openstack-config --set /etc/cinder/cinder.conf DEFAULT kombu_ssl_ca_certs /path/to/ca.crt

# Configure block storage database connection
openstack-config --set /etc/cinder/cinder.conf database connection mysql://cinder:${cinder_db_pw}@${mariadb_ip}/cinder
openstack-config --set /etc/cinder/cinder.conf database idle_timeout 3600

# Additional Cinder configuration 
openstack-config --set /etc/cinder/cinder.conf notification_driver cinder.openstack.common.notifier.rpc_notifier
openstack-config --set /etc/cinder/cinder.conf control_exchange openstack
openstack-config --set /etc/cinder/cinder.conf osapi_volume_listen 0.0.0.0

# Cinder Swift backup --optional--
##backup_swift_url=http://192.168.122.181:8080/v1/AUTH_
##backup_swift_container=volumes_backup
##backup_swift_object_size=52428800
##backup_swift_retry_attempts=3
##backup_swift_retry_backoff=2
##backup_driver=cinder.backup.drivers.swift

openstack-config --set /etc/cinder/cinder.conf DEFAULT api_paste_config /etc/cinder/api-paste.ini
openstack-config --set /etc/cinder/cinder.conf DEFAULT glance_host ${glance_ip}
openstack-config --set /etc/cinder/cinder.conf DEFAULT backup_topic cinder-backup
openstack-config --set /etc/cinder/cinder.conf DEFAULT backup_manager cinder.backup.manager.BackupManager
openstack-config --set /etc/cinder/cinder.conf DEFAULT backup_api_class cinder.backup.api.API
openstack-config --set /etc/cinder/cinder.conf DEFAULT backup_name_template backup-%s
openstack-config --set /etc/cinder/cinder.conf DEFAULT debug False
openstack-config --set /etc/cinder/cinder.conf DEFAULT verbose True
openstack-config --set /etc/cinder/cinder.conf DEFAULT log_dir /var/log/cinder
openstack-config --set /etc/cinder/cinder.conf DEFAULT use_syslog False
openstack-config --set /etc/cinder/cinder.conf DEFAULT volume_backend_name DEFAULT


# iptables firewall to allow block storage traffic 
iptables -I INPUT -p tcp -m multiport --dports 3260,8776 -m comment --comment "cinder incoming" -j ACCEPT
service iptables save; service iptables restart

# Populate the cinder database
chown cinder:cinder /var/log/cinder/cinder-manage.log
su -s /bin/sh -c "cinder-manage db sync" cinder

# Increate the throughput of the block storage API service
#####openstack-config --set /etc/cinder/cinder.conf DEFAULT osapi_volume_workers CORES
### Note - packstack doesn't set this...

# Volume Service - LVM Backend (Block Storage Node)
#yum -y install openstack-cinder
##### Create /etc/cinder/cinder.conf as above...  Or copy over... your choice
#pvcreate /dev/sdXX
#vgcreate cinder-volumes /dev/sdXX
#openstack-config --set /etc/cinder/cinder.conf DEFAULT volume_group cinder-volumes
#openstack-config --set /etc/cinder/cinder.conf DEFAULT volume_driver cinder.volume.drivers.lvm.LVMISCSIDriver

# Setup iSCSI Target (iSCSI Server)
#yum -y install targetcli
#systemctl enable target
#systemctl start target
##### NOTE - This is tgtd on RHEL 6

  # Add a filter in LVM.conf to keep LVM from scanning devices of virtual machines
  ## ssh $blocknode "sed -i '/# volume_list =/a volume_list = [ \"rhel\", \"cinder-volumes\", \"@uclactr003\", \"@uclactr003.mia.ucloud.int\" ]' /etc/lvm/lvm.conf"
  ### Didn't get this automated, but we want to do: 
  # filter = [ "a/sda1/", "a/sdb/", "r/.*/"]

openstack-config --set /etc/cinder/cinder.conf DEFAULT iscsi_helper lioadm

openstack-config --set /etc/cinder/cinder.conf DEFAULT iscsi_ip_address $(hostname -i)

# Ensure /etc/tgt/targets.conf has "include /etc/cinder/volumes/*"

# Start and enable Cinder services
systemctl enable openstack-cinder-api
systemctl enable openstack-cinder-scheduler
systemctl enable openstack-cinder-volume
systemctl start openstack-cinder-api
systemctl start openstack-cinder-scheduler
systemctl start openstack-cinder-volume

# Validate the block storage service installlation
source ~/keystonerc_admin
cinder list
cinder create --display-name testvol 1
cinder show testvol
cinder delete testvol

#### NOTE - WE REALLY NEED TO TEST ATTACHING AS WELL 
#### AND NEED TO TEST CREATING ON ALL BACKEND NODES 
#### AND ATTACHING TO ALL COMPUTE NODES
#### WHY AM I SHOUTING?

