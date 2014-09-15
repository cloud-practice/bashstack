#!/bin/bash
##########################################################################
# Module:	swift
# Description:	Install Swift Object Storage Service
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

#### NOTE - Will likely want to break this down at least into proxy vs storage node

yum -y install openstack-swift-proxy openstack-swift-object openstack-swift-container openstack-swift-account openstack-utils memcached

# Configuring Object Storage to Authenticate with Keystone
source ~/keystonerc_admin
keystone user-create --name swift --pass ${swift_pw}
keystone user-role-add --user swift --role admin --tenant services
keystone service-create --name swift --type object-store --description "Swift Storage Service"

keystone endpoint-create --service swift --publicurl "http://${swift_ip_public}:8080/v1/AUTH_\$(tenant_id)s" --adminurl "http://${swift_ip_admin}:8080/v1" --internalurl "http://${swift_ip_internal}:8080/v1/AUTH_\$(tenant_id)s"

#### NOTE - THERE SHOULD ALSO BE A swift_s3 SERVICE!  Validate this as I just made it up:
# keystone service-create --name swift_s3 --type s3 --description "Openstack S3 Service"
# keystone endpoint-create --service swift_s3 --publicurl "http://IP:8080" --adminurl "http://IP:8080" --internalurl "http://IP:8080"

# Configure the Storage Nodes
# Format your devices as xfs - make sure xattrs are enabled 
# /dev/sdb1 /srv/node/d1 ext4 acl,user_xattr 0 0
# Add your devices to /etc/fstab and mount under /srv/node/ at boot time.  Mount with your devices unique ID found in 'blkid' 

# iptables firewall rules
  # 873  = rsync
  # 6000 = object service
  # 6001 = container service
  # 6002 = account service
iptables -I INPUT -p tcp -m multiport --dports 6000,6001,6002,873 -m comment --comment "swift incoming" -j ACCEPT
service iptables save; service iptables restart

# Correct Ownership 
chown -R swift:swift /srv/node/
restorecon -R /srv

# Create a swift hash prefix / suffix
openstack-config --set /etc/swift/swift.conf swift-hash swift_hash_path_prefix $(openssl rand -hex 10)
openstack-config --set /etc/swift/swift.conf swift-hash swift_hash_path_suffix $(openssl rand -hex 10)


# Set the IP address that your storage node will listen on
openstack-config --set /etc/swift/object-server.conf DEFAULT bind_ip $(hostname -i)
openstack-config --set /etc/swift/account-server.conf DEFAULT bind_ip $(hostname -i)
openstack-config --set /etc/swift/container-server.conf DEFAULT bind_ip $(hostname -i)

# Copy /etc/swift.conf from the node you are currently configuring to all nodes....
scp blah blah blah

# Start and enable services on your Swift Storage Node
systemctl enable openstack-swift-account
systemctl enable openstack-swift-container
systemctl enable openstack-swift-object
systemctl start openstack-swift-account
systemctl start openstack-swift-container
systemctl start openstack-swift-object

# Configure the Proxy Service
openstack-config --set /etc/swift/proxy-server.conf filter:authtoken auth_host ${keystone_ip}
openstack-config --set /etc/swift/proxy-server.conf filter:authtoken auth_port 35357
openstack-config --set /etc/swift/proxy-server.conf filter:authtoken auth_protocol http
openstack-config --set /etc/swift/proxy-server.conf filter:authtoken auth_uri http://${keystone_ip}:5000/
openstack-config --set /etc/swift/proxy-server.conf filter:authtoken admin_tenant_name services
openstack-config --set /etc/swift/proxy-server.conf filter:authtoken admin_user swift
openstack-config --set /etc/swift/proxy-server.conf filter:authtoken admin_password ${swift_pw}

# Change ownership of the keystone signing directory
  # Add check if exists?  Do aftre starting swift? 
chown swift:swift /tmp/keystone-signing-swift

# Start and enable services on your Swift Proxy Node
systemctl enable memcached
systemctl enable openstack-swift-proxy
systemctl start memcached
systemctl start openstack-swift-proxy

# iptables firewall rule to allow incoming connections to Swift Proxy
iptables -I INPUT -p tcp -m multiport --dports 8080 -m comment --comment "swift proxy incoming" -j ACCEPT
service iptables save; service iptables restart

# Build Rings 
swift-ring-builder /etc/swift/object.builder create part_power replica_count min_part_hours
swift-ring-builder /etc/swift/container.builder create part_power replica_count min_part_hours
swift-ring-builder /etc/swift/account.builder create part_power replica_count min_part_hours

### Guess this needs to be a storage node IP???  Needs work.. 
# Add devices to Rings 
swift-ring-builder /etc/swift/account.builder add zX-SERVICE_IP:6002/dev_mountpt part_count
# For Example: swift-ring-builder /etc/swift/account.builder add z1-10.64.115.44:6002/accounts 100

# Repeat this step on each node in the cluster you want added to the ring

# Add devices for container and account similarly
swift-ring-builder /etc/swift/container.builder add zX-SERVICE_IP:6001/dev_mountpt part_count
swift-ring-builder /etc/swift/object.builder add zX-SERVICE_IP:6000/dev_mountpt part_count

# Distribute the partitions across the devices
swift-ring-builder /etc/swift/account.builder rebalance
swift-ring-builder /etc/swift/container.builder rebalance
swift-ring-builder /etc/swift/object.builder rebalance

# Validate you have 3 .gz files for the rings:
# /etc/swift/account.ring.gz /etc/swift/container.ring.gz /etc/swift/object.ring.gz
ls /etc/swift/*gz

# Ensure correct ownership
chown -R root:swift /etc/swift

# Copy the ring to each node in the cluster 
scp /etc/swift/*.gz node_ip_address:/etc/swift

# Validate Object Storage Service
source ~/keystonerc_admin
swift list
head -c 1024 /dev/urandom > data1.file ; swift upload c1 data1.file
head -c 1024 /dev/urandom > data2.file ; swift upload c1 data2.file
head -c 1024 /dev/urandom > data3.file ; swift upload c1 data3.file
swift list
swift list c1
find /srv/node/ -type f -name "*data"
rm -f data*.file
# Probably want to swift delete the files too... 


