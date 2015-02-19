#!/bin/bash
##########################################################################
# Module:	swift_storage
# Description:	Install Swift Object Storage - Storage Node
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

yum -y install xfsprogs rsync openstack-swift-object openstack-swift-container openstack-swift-account openstack-utils

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

# Create the recon directory and ensure proper ownership 
mkdir -p /var/cache/swift
chown -R swift:swift /var/cache/swift

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


