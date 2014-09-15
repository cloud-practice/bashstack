#!/bin/bash
##########################################################################
# Module:	rabbitmq
# Description:	Install RabbitMQ
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi


# Set firewall rule to allow incoming traffic
iptables -I INPUT -p tcp --dports 5672 -m comment --comment "amqp incoming" -j ACCEPT
iptables -I INPUT -p tcp --dports 5671 -m comment --comment "amqp SSL incoming" -j ACCEPT
service iptables save
service iptables restart

# Install rabbitmq
yum -y install rabbitmq-server

# Start and enable rabbitmq
systemctl start rabbitmq-server.service
systemctl enable rabbitmq-server.service

# Enable Authentication
rabbitmqctl delete_user guest
rabbitmqctl add_user ${amqp_auth_user} ${amqp_auth_pw}
rabbitmqctl set_permissions ${amqp_auth_user} ".*" ".*" ".*"
rabbitmqctl set_user_tags ${amqp_auth_user} administrator


### Note a guest user / guest password is automatically created.  You'll want
### to change this! 
systemctl start rabbitmq-server.service
systemctl enable rabbitmq-server.service

##### ADD CHECK TO VALIDATE RABBIT IS UP PRIOR TO MOVING FORWARD?

# NOTE - Chapter 2 of the CL315 training course on rabbit has good way to test functionality

# Create RabbitMQ User accounts:
rabbitmqctl add_user cinder $cinder_pw
rabbitmqctl add_user glance $glance_pw
rabbitmqctl add_user heat $heat_pw
rabbitmqctl add_user nova $nova_pw
rabbitmqctl add_user neutron $neutron_pw
rabbitmqctl add_user trove $trove_pw
##### Note - it looks like these aren't needed.  Packstack just uses amqp_user
### Although amqp_user would be an administrator :/
rabbitmqctl list_users

# Create certificates for RabbitMQ SSL Communication 
#mkdir /etc/pki/rabbitmq
#echo $amqp_ssl_cert_pw > /etc/pki/rabbitmq/certpw
#chmod 700 /etc/pki/rabbitmq
#chmod 600 /etc/pki/rabbitmq/certpw
### Create unsigned cert???
#certutil -N -d /etc/pki/rabbitmq -f certpw

# Create Self-Signed Cert 
#certutil -S -d /etc/pki/rabbitmq -n ${amqp_ip} -s "CN=${amqp_ip}" -t "CT,," -x -f certpw -z /usr/bin/certutil


### For a 3rd party Cert Authority (recommended for prod)  create a signing request
#certutil -R -d /etc/pki/rabbitmq -s "CN=RABBITMQ_HOST" -a -f certpw > RABBITMQ_HOST.csr
# Add the cert files to your database
# certutil -A -d /etc/pki/rabbitmq -n RABBITMQ_HOST -f certpw -t u,u,u -a -i /path/to/server.crt
# certutil -A -d /etc/pki/rabbitmq -n "Your CA certificate" -f certpw -t CT,C,C -a -i /path/to/ca.crt
#####

# If SSL enabled, export SSL to the clients
# pk12util -o <p12exportfile> -n <certname> -d <certdir> -w <p12filepwfile>
# openssl pkcs12 -in <p12exportfile> -out <clcertname> -nodes -clcerts -passin pass:<p12pw>


