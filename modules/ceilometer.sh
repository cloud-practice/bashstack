#!/bin/bash
##########################################################################
# Module:	ceilometer
# Description:	Install Ceilometer Telemetry Service
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

yum -y install openstack-ceilometer-api openstack-ceilometer-central openstack-ceilometer-collector openstack-ceilometer-common openstack-ceilometer-alarm python-ceilometer python-ceilometerclient

# Create firewall rules
if [[ $firewall == "firewalld" ]] ; then
  # Ceilometer API
  firewall-cmd --add-port=8777/tcp
  firewall-cmd --add-port=8777/tcp --permanent
  # Ceilometer Collector
  firewall-cmd --add-port=4952/udp
  firewall-cmd --add-port=4952/udp --permanent
elif  [[ $firewall == "iptables" ]] ; then
  iptables -I INPUT -p tcp -m multiport --dports 8777 -m comment --comment "ceilometer api incoming" -j ACCEPT
  iptables -I INPUT -p udp -m multiport --dports 4952 -m comment --comment "ceilometer collector incoming" -j ACCEPT
  service iptables save; service iptables restart
else
  echo "No firewall rules created as firewalld and iptables are inactive"
fi

if [[ $(hostname -s) == $ceilometer_bootstrap_node ]]; then
  # Create the Ceilometer records in keystone:
  source ~/keystonerc_admin
  keystone user-create --name=ceilometer --pass=${ceilometer_pw}
  keystone role-create --name=ResellerAdmin
  keystone user-role-add --user ceilometer --role ResellerAdmin --tenant services --role ResellerAdmin
  keystone user-role-add --user ceilometer --role admin --tenant services
  keystone service-create --name=ceilometer --type=metering --description="OpenStack Telemetry Service"
  keystone endpoint-create --service ceilometer --publicurl "${ceilometer_ip_public}:8777" --adminurl "${ceilometer_ip_admin}:8777" --internalurl "${ceilometer_ip_internal}:8777"
  ### region support??? 
fi
source ~/keystonerc_admin

# Configure Telemetry Service Auth 
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_host ${keystone_ip}
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_protocol http
#openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_uri http://${keystone_ip}:5000/
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_user ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_password ${ceilometer_pw}
openstack-config --set /etc/ceilometer/ceilometer.conf publisher_rpc metering_secret ${ceilometer_metering_secret}

openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_auth_url http://${keystone_ip}:5000/v2.0 
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_username ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_tenant_name services
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_password ${ceilometer_pw}

# Configure memcache nodes
memcnodesarray=($memcache_nodes)
for memcnode in "${memcnodesarray[@]}"
do
  memcstring="${memcstring}${memcnode}:11211,"
done
memcache_nodes_final=$(echo $memcstring | sed 's/,$//')
openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT memcache_servers ${memcache_nodes_final}


# Configure Ceilometer AMQP 
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rpc_backend ceilometer.openstack.common.rpc.impl_kombu
if [[ $ha == y ]]; then
  rabbit_nodes_cs=$(sed -e 's/ /,/g' ${rabbit_nodes})
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_hosts ${rabbit_nodes_cs}
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_ha_queues True
else
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_host ${amqp_ip}
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_ha_queues False
fi
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_port 5672
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_userid ${amqp_auth_user}
  openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_pass ${amqp_auth_pw}

  #*********** RABBIT SSL SETTINGS ***************
  ### If SSL enabled on RabbitMQ
  #openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT rabbit_use_ssl True
  #openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT kombu_ssl_certfile /path/to/client.crt
  #openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key
  ### If Certs Signed by 3rd Party, also add this
  #openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT kombu_ssl_ca_certs /path/to/ca.crt


# Create Telemetry Service Endpoints
openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT os_auth_url http://${keystone_ip}:35357/v2.0
openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT os_username ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT os_tenant_name services
openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT os_password ${ceilometer_pw}

# Configure Telemetry DB Connection 
if [[ $ha == "y" ]]; then
  # Configure memcache nodes
   mongonodesarray=($mongo_nodes)
   for mongonode in "${mongonodesarray[@]}"
   do
      mongostring="${mongostring}${mongonode},"
   done
   mongo_nodes_final=$(echo $mongostring | sed 's/,$//')

  openstack-config --set /etc/ceilometer/ceilometer.conf database connection mongodb://${mongo_nodes_final}:27017/ceilometer?replicaSet=ceilometer
else
  openstack-config --set /etc/ceilometer/ceilometer.conf database connection mongodb://${mongo_ip}:27017/ceilometer
fi

# Keep only the last 5 days data (value is in secs)
# keep last 5 days data only (value is in secs)
openstack-config --set /etc/ceilometer/ceilometer.conf database time_to_live 432000
openstack-config --set /etc/ceilometer/ceilometer.conf api host <<< NEED TO ADD BIND IP HERE >>> 

if [[ $ha == "y" ]] ; then
  if [[ $ha_type == "pacemaker" ]]; then
    openstack-config --set /etc/ceilometer/ceilometer.conf coordination backend_url 'redis://${redis_ip}:6379'
  elif [[ $ha_type == "keepalived" ]]; then
    # Add redis coordination URL
    redisnodesarray=($redis_nodes)
    for redisnode in "${redisnodesarray[@]}"
    do
      if [[ $redisnode == $redis_bootstrap_node ]]; then
        redis_string="redis://${redisnode}:26379?sentinel=mymaster"
      else
        redis_string="${redis_string}&sentinel_fallback=${redisnode}:26379"
      fi
    done
    # String Example: redis://hacontroller1:26379?sentinel=mymaster&sentinel_fallback=hacontroller2:26379&sentinel_fallback=hacontroller3:26379
    openstack-config --set /etc/ceilometer/ceilometer.conf coordination backend_url '${redis_string}'
  fi
fi


