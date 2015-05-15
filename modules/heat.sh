#!/bin/bash
##########################################################################
# Module:	heat
# Description:	Install Heat Orchestration Service
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi


# Install services
yum -y install openstack-heat-api openstack-heat-api-cfn openstack-heat-common openstack-heat-engine openstack-heat-api-cloudwatch heat-cfntools python-heatclient openstack-utils python-openstackclient openstack-heat-templates

# Firewall rules for Heat
if [[ $firewall == "firewalld" ]] ; then
  firewall-cmd --add-port=8000/tcp
  firewall-cmd --add-port=8000/tcp --permanent
  firewall-cmd --add-port=8003/tcp
  firewall-cmd --add-port=8003/tcp --permanent
  firewall-cmd --add-port=8004/tcp
  firewall-cmd --add-port=8004/tcp --permanent
elif  [[ $firewall == "iptables" ]] ; then
  iptables -I INPUT -p tcp -m multiport --dports 8000,8003,8004 -m comment --comment "heat incoming" -j ACCEPT
  service iptables save; service iptables restart
else
  echo "No firewall rules created as firewalld and iptables are inactive"
fi

# Configuring heat database
if [ ! -f /root/.my.cnf ] ; then    # Need password-less mysql access
  echo "ERROR - /root/.my.cnf doesn't exist" 
  exit 1
fi

if [[ $(hostname -s) == $heat_bootstrap_node ]]; then

mysql -u root << EOF
CREATE DATABASE heat;
GRANT ALL ON heat.* TO 'heat'@'%' IDENTIFIED BY '${heat_db_pw}';
GRANT ALL ON heat.* TO 'heat'@'localhost' IDENTIFIED BY '${heat_db_pw}';
FLUSH PRIVILEGES;
quit
EOF

source /root/keystonerc_admin

  # Create the Orchestration keystone records
  source ~/keystonerc_admin
  keystone user-create --name=heat --pass=SERVICE_PASSWORD
  keystone user-role-add --user heat --role admin --tenant services
  keystone service-create --name heat --type orchestration
  keystone service-create --name heat-cfn --type cloudformation
  keystone endpoint-create --service heat-cfn --publicurl "${heat_ip_public}:8000/v1" --adminurl "${heat_ip_admin}:8000/v1" --internalurl "${heat_ip_internal}:8000/v1"
  keystone endpoint-create --service heat --publicurl "${heat_ip_public}:8004/v1/%(tenant_id)s" --adminurl "${heat_ip_admin}:8004/v1/%(tenant_id)s" --internalurl "${heat_ip_internal}:8004/v1/%(tenant_id)s"
    # Region support needed ?

  keystone role-create --name heat_stack_user

  # Create the identity domain for Orchestration
  ADMIN_TOKEN=${keystone_admin_token}

  heat-keystone-setup-domain --stack-domain-admin ${stack_domain_admin} --stack-domain-admin-password ${stack_domain_admin_password} --stack-user-domain-name ${stack_user_domain}
fi

source /root/keystonerc_admin

openstack-config --set /etc/heat/heat.conf DEFAULT stack_domain_admin_password ${stack_domain_admin_password}
openstack-config --set /etc/heat/heat.conf DEFAULT stack_domain_admin ${stack_domain_admin}
openstack-config --set /etc/heat/heat.conf DEFAULT stack_user_domain ${stack_user_domain}

# Configure Orchestration Service Authentication
openstack-config --set /etc/heat/heat.conf database connection mysql://heat:${heat_db_pw}@${mariadb_ip}/heat
openstack-config --set /etc/heat/heat.conf database database max_retries -1

openstack-config --set /etc/heat/heat.conf heat_api bind_host $(hostname -i)
openstack-config --set /etc/heat/heat.conf heat_api_cfn bind_host $(hostname -i)
openstack-config --set /etc/heat/heat.conf heat_api_cloudwatch bind_host $(hostname -i)

openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_user heat
openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_password ${heat_pw}
openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_host ${keystone_ip}
openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_uri http://${keystone_ip}:35357/v2.0
openstack-config --set /etc/heat/heat.conf keystone_authtoken keystone_ec2_uri http://${keystone_ip}:35357/v2.0

# Configure memcache nodes
memcnodesarray=($memcache_nodes)
for memcnode in "${memcnodesarray[@]}"
do
  memcstring="${memcstring}${memcnode}:11211,"
done
memcache_nodes_final=$(echo $memcstring | sed 's/,$//')
openstack-config --set /etc/heat/heat.conf DEFAULT memcache_servers ${memcache_nodes_final}

# Configure Heat-api-cfn / cloudwatch service hostnames
openstack-config --set /etc/heat/heat.conf DEFAULT heat_metadata_server_url http://${heat_ip}:8000
openstack-config --set /etc/heat/heat.conf DEFAULT heat_waitcondition_server_url http://${heat_ip}:8000/v1/waitcondition
openstack-config --set /etc/heat/heat.conf DEFAULT heat_watch_server_url http://${heat_ip}:8003

# Configure user that will receive heat wait conditions
openstack-config --set /etc/heat/heat.conf DEFAULT heat_stack_user_role heat_stack_user

# Configure RabbitMQ Message Broker Settings for the Orchestration Service
openstack-config --set /etc/heat/heat.conf DEFAULT rpc_backend heat.openstack.common.rpc.impl_kombu
if [[ $ha == y ]]; then
  rabbit_nodes_cs=$(sed -e 's/ /,/g' ${rabbit_nodes})
  openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_hosts ${rabbit_nodes_cs}
  openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_ha_queues True
else
  openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_host ${amqp_ip}
  openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_ha_queues False
fi
  openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_port 5672
  openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_userid ${amqp_auth_user}
  openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_pass ${amqp_auth_pw}

#*********** RABBIT SSL SETTINGS ***************
### If SSL enabled on RabbitMQ
#openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_use_ssl True
# openstack-config --set /etc/heat/heat.conf DEFAULT kombu_ssl_certfile /path/to/client.crt
# openstack-config --set /etc/heat/heat.conf DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key 
### If Certs Signed by 3rd Party, also add this
#openstack-config --set /etc/heat/heat.conf DEFAULT kombu_ssl_ca_certs /path/to/ca.crt

if [[ $(hostname -s) == $heat_bootstrap_node ]]; then
  su heat -s /bin/sh heat -c "heat-manage db_sync"
fi



