#!/bin/bash
##########################################################################
# Module:	swift_proxy
# Description:	Install Swift Object Storage Proxy Server
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

#### NOTE - Will likely want to break this down at least into proxy vs storage node

yum -y install openstack-swift-proxy python-swiftclient python-keystone-auth-token python-keystonemiddleware openstack-utils memcached curl

# Configuring Object Storage to Authenticate with Keystone
source ~/keystonerc_admin
keystone user-create --name swift --pass ${swift_pw}
keystone user-role-add --user swift --role admin --tenant services
keystone role-create --name SwiftOperator
keystone service-create --name swift --type object-store --description "OpenStack Object Storage "

keystone endpoint-create --service swift --publicurl "http://${swift_ip_public}:8080/v1/AUTH_\$(tenant_id)s" --adminurl "http://${swift_ip_admin}:8080/v1" --internalurl "http://${swift_ip_internal}:8080/v1/AUTH_\$(tenant_id)s" --region RegionOne

keystone service-create --name s3 --type s3 --description "OpenStack S3 Service"
keystone endpoint-create --service s3 --publicurl 'http://10.55.0.10:8080' --internalurl 'http://10.55.0.10:8080' --adminurl 'http://10.55.0.10:8080' --region RegionOne

# Create a swift hash prefix / suffix
openstack-config --set /etc/swift/swift.conf swift-hash swift_hash_path_prefix $(openssl rand -hex 10)
openstack-config --set /etc/swift/swift.conf swift-hash swift_hash_path_suffix $(openssl rand -hex 10)

# Configure the Proxy Service
cat << EOF >> /etc/swift/proxy-server.conf
[DEFAULT]
bind_port = 8080

bind_ip = 192.168.122.69

workers = 4
user = swift
log_name = swift
log_facility = LOG_LOCAL1
log_level = INFO
log_headers = False
log_address = /dev/log



[pipeline:main]
pipeline = catch_errors bulk healthcheck cache crossdomain ratelimit authtoken keystone staticweb tempurl slo formpost account_quotas container_quotas proxy-server

[app:proxy-server]
use = egg:swift#proxy
set log_name = proxy-server
set log_facility = LOG_LOCAL1
set log_level = INFO
set log_address = /dev/log
log_handoffs = true
allow_account_management = true
account_autocreate = true




[filter:bulk]
use = egg:swift#bulk
max_containers_per_extraction = 10000
max_failed_extractions = 1000
max_deletes_per_request = 10000
yield_frequency = 60


[filter:authtoken]
log_name = swift
signing_dir = /var/cache/swift
paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
auth_host = ${keystone_ip}
auth_port = 35357
auth_protocol = http
auth_uri = http://${keystone_ip}:5000
admin_tenant_name = services
admin_user = swift
admin_password = ${swift_pw}
delay_auth_decision = 1
cache = swift.cache
include_service_catalog = False
[filter:cache]
use = egg:swift#memcache
memcache_servers = 127.0.0.1:11211
[filter:catch_errors]
use = egg:swift#catch_errors


[filter:healthcheck]
use = egg:swift#healthcheck

[filter:ratelimit]
use = egg:swift#ratelimit
clock_accuracy = 1000
max_sleep_time_seconds = 60
log_sleep_time_seconds = 0
rate_buffer_seconds = 5
account_ratelimit = 0


[filter:tempurl]
use = egg:swift#tempurl


[filter:formpost]
use = egg:swift#formpost


[filter:staticweb]
use = egg:swift#staticweb

[filter:crossdomain]
use = egg:swift#crossdomain
cross_domain_policy = <allow-access-from domain="*" secure="false" />

[filter:slo]
use = egg:swift#slo
max_manifest_segments = 1000
max_manifest_size = 2097152
min_segment_size = 1048576
rate_limit_after_segment = 10
rate_limit_segments_per_sec = 0
max_get_time = 86400

[filter:keystone]
use = egg:swift#keystoneauth
operator_roles = admin, SwiftOperator
is_admin = true

[filter:account_quotas]
use = egg:swift#account_quotas


[filter:container_quotas]
use = egg:swift#container_quotas
EOF

chown swift:swift /etc/swift/proxy-server.conf
chmod 660 /etc/swift/proxy-server.conf

#openstack-config --set /etc/swift/proxy-server.conf filter:authtoken auth_host ${keystone_ip}
#openstack-config --set /etc/swift/proxy-server.conf filter:authtoken auth_port 35357
#openstack-config --set /etc/swift/proxy-server.conf filter:authtoken auth_protocol http
#openstack-config --set /etc/swift/proxy-server.conf filter:authtoken auth_uri http://${keystone_ip}:5000/
#openstack-config --set /etc/swift/proxy-server.conf filter:authtoken admin_tenant_name services
#openstack-config --set /etc/swift/proxy-server.conf filter:authtoken admin_user swift
#openstack-config --set /etc/swift/proxy-server.conf filter:authtoken admin_password ${swift_pw}

# Change ownership of the keystone signing directory
  # Add check if exists?  Do aftre starting swift? 
#chown swift:swift /tmp/keystone-signing-swift

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


