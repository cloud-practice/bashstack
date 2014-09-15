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
yum -y install openstack-heat-api openstack-heat-api-cfn openstack-heat-common openstack-heat-engine openstack-heat-api-cloudwatch heat-cfntools python-heatclient openstack-utils

# Configuring heat database
if [ ! -f /root/.my.cnf ] ; then    # Need password-less mysql access
  echo "ERROR - /root/.my.cnf doesn't exist" 
  exit 1
fi
mysql -u root << EOF
CREATE DATABASE heat;
GRANT ALL ON heat.* TO 'heat'@'%' IDENTIFIED BY '${heat_db_pw}';
GRANT ALL ON heat.* TO 'heat'@'localhost' IDENTIFIED BY '${heat_db_pw}';
FLUSH PRIVILEGES;
quit
EOF

source /root/keystonerc_admin

openstack-config --set /etc/heat/heat.conf database connection mysql://heat:${heat_db_pw}@${mariadb_ip}/heat

runuser -s /bin/sh heat -c "heat-manage db_sync"

# Restrict the bind addresses for each API service
openstack-config --set /etc/heat/heat.conf heat_api bind_host $(hostname -i)
openstack-config --set /etc/heat/heat.conf heat_api_cfn bind_host $(hostname -i)
openstack-config --set /etc/heat/heat.conf heat_api_cloudwatch bind_host $(hostname -i)

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
yum -y install python-openstackclient
ADMIN_TOKEN=$(cat /etc/keystone/keystone.conf | grep "^admin_token" | awk -F "=" '{print $2}')

heat-keystone-setup-domain > /tmp/heatoutput.txt
stack_user_domain=$(cat /tmp/heatoutput.txt | grep "stack_user_domain" | awk -F "=" '{print $2}')
stack_domain_admin=$(cat /tmp/heatoutput.txt | grep "stack_domain_admin" | awk -F "=" '{print $2}')
stack_domain_admin_password=$(cat /tmp/heatoutput.txt | grep "stack_domain_admin_password" | awk -F "=" '{print $2}')

openstack-config --set /etc/heat/heat.conf DEFAULT stack_domain_admin_password ${stack_domain_admin_password}
openstack-config --set /etc/heat/heat.conf DEFAULT stack_domain_admin ${stack_domain_admin}
openstack-config --set /etc/heat/heat.conf DEFAULT stack_user_domain ${stack_user_domain}

# Configure Orchestration Service Authentication
openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_tenant_name services
openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_user heat
openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_password ${heat_pw}
openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_host ${keystone_ip}
openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_uri http://${keystone_ip}:35357/v2.0
openstack-config --set /etc/heat/heat.conf keystone_authtoken keystone_ec2_uri http://${keystone_ip}:35357/v2.0

# Configure Heat-api-cfn / cloudwatch service hostnames
openstack-config --set /etc/heat/heat.conf DEFAULT heat_metadata_server_url http://${heat_ip}:8000
openstack-config --set /etc/heat/heat.conf DEFAULT heat_waitcondition_server_url http://${heat_ip}:8000/v1/waitcondition
openstack-config --set /etc/heat/heat.conf DEFAULT heat_watch_server_url http://${heat_ip}:8003

# Configure user that will receive heat wait conditions
openstack-config --set /etc/heat/heat.conf DEFAULT heat_stack_user_role heat_stack_user

# Configure RabbitMQ Message Broker Settings for the Orchestration Service
openstack-config --set /etc/heat/heat.conf DEFAULT rpc_backend heat.openstack.common.rpc.impl_kombu
openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_host ${amqp_ip}
openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_port 5672
openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_userid ${amqp_auth_user}
openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_pass ${amqp_auth_pw}
#*********** RABBIT HA SETTINGS ***************
### If SSL enabled on RabbitMQ
#openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_use_ssl True
# openstack-config --set /etc/heat/heat.conf DEFAULT kombu_ssl_certfile /path/to/client.crt
# openstack-config --set /etc/heat/heat.conf DEFAULT kombu_ssl_keyfile /path/to/clientkeyfile.key 
### If Certs Signed by 3rd Party, also add this
#openstack-config --set /etc/heat/heat.conf DEFAULT kombu_ssl_ca_certs /path/to/ca.crt

# iptables rules for Heat
iptables -I INPUT -p tcp -m multiport --dports 8000,8003,8004 -m comment --comment "heat incoming" -j ACCEPT
service iptables save; service iptables restart

# Launch the Orchestration Service
systemctl enable openstack-heat-api
systemctl enable openstack-heat-api-cfn
systemctl enable openstack-heat-api-cloudwatch
systemctl enable openstack-heat-engine
systemctl start openstack-heat-api
systemctl start openstack-heat-api-cfn
systemctl start openstack-heat-api-cloudwatch
systemctl start openstack-heat-engine

# Deploy a Stack using orchestration templates
yum -y install openstack-heat-templates

### Need to write a few custom validations I think....  
### NOTE - If we're using ceilometer metrics for cloudwatch, we'll want that done
### prior to deploying heat!


