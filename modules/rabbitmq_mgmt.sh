#!/bin/bash
##########################################################################
# Module:	rabbitmq_mgmt
# Description:	Install RabbitMQ Web Management Console
##########################################################################

/usr/lib/rabbitmq/bin/rabbitmq-plugins enable rabbitmq_management
/usr/lib/rabbitmq/bin/rabbitmq-plugins list

# Set firewall rule to allow incoming traffic
iptables -I INPUT -p tcp -m multiport --dports 15672 -m comment --comment "rabbitmq mgmt console incoming" -j ACCEPT
service iptables save
service iptables restart

# Allow rabbitmq to successfully bind the management port
yum -y install policycoreutils-python
semanage port -a -t amqp_port_t -p tcp 15672

# Restart rabbitmq for the changes to take effect
systemctl restart rabbitmq-server
