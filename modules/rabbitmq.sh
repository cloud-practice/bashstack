#!/bin/bash
##########################################################################
# Module:	rabbitmq
# Description:	Install RabbitMQ
##########################################################################

### TODO: Add SSL Support


ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# Firewall rules for RabbitMQ:
if [[ $(systemctl is-active firewalld) == "active" ]] ; then
  firewall-cmd --add-port=5671/tcp
  firewall-cmd --add-port=5671/tcp --permanent
  firewall-cmd --add-port=5672/tcp
  firewall-cmd --add-port=5672/tcp --permanent
  firewall-cmd --add-port=4369/tcp
  firewall-cmd --add-port=4369/tcp --permanent
  firewall-cmd --add-port=44001/tcp
  firewall-cmd --add-port=44001/tcp --permanent
elif  [[ $(systemctl is-active iptables) == "active" ]] ; then
  iptables -I INPUT -p tcp -m multiport --dports 5671 -m comment --comment "amqp SSL incoming" -j ACCEPT
  iptables -I INPUT -p tcp -m multiport --dports 5672 -m comment --comment "amqp incoming" -j ACCEPT
  iptables -I INPUT -p tcp -m multiport --dports 4369 -m comment --comment "amqp epmd" -j ACCEPT
  iptables -I INPUT -p tcp -m multiport --dports 44001 -m comment --comment "amqp rabbit" -j ACCEPT
  service iptables save; service iptables restart
else
  echo "No firewall rules created as firewalld and iptables are inactive"
fi

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

systemctl stop rabbitmq-server.servie

# Write rabbitmq.config
if [[ $ha == "y" ]]; then
RABBIT_CLUSTER_STRING=""
  for node in $rabbit_nodes
  do 
    RABBIT_CLUSTER_STRING="'rabbit@${node}', "
  done
  RABBIT_CLUSTER_STRING=$(sed 's/, $//' $RABBIT_CLUSTER_STRING)
  # NOTE: string should look like: 'rabbit@hacontroller1', 'rabbit@hacontroller2', 'rabbit@hacontroller3'

  cat << EOF > /etc/rabbitmq/rabbitmq.config
[
  {rabbit, [
    {cluster_nodes, {[${RABBIT_CLUSTER_STRING}], disc}},
    {cluster_partition_handling, ignore},
    {default_user, <<"${amqp_auth_user}">>},
    {default_pass, <<"${amqp_auth_pw}">>},
    {tcp_listen_options, [binary,
        {packet, raw},
        {reuseaddr, true},
        {backlog, 128},
        {nodelay, true},
        {exit_on_close, false},
        {keepalive, true}]}
  ]},
  {kernel, [
        {inet_dist_listen_max, 44001},
        {inet_dist_listen_min, 44001}
  ]}
].
EOF

  cat > /etc/sysctl.d/tcpka.conf << EOF
net.ipv4.tcp_keepalive_intvl = 1
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_time = 5
EOF

sysctl -p /etc/sysctl.d/tcpka.conf
  
else
  cat << EOF > /etc/rabbitmq/rabbitmq.config
[
  {rabbit, [
    {default_user, <<"${amqp_auth_user}">>},
    {default_pass, <<"${amqp_auth_pw}">>}
  ]},
  {kernel, [

  ]}
].
EOF
fi

# Write rabbitmq-env.config
### NOTE: This would be different with SSL!
cat << EOF >> /etc/rabbitmq/rabbitmq-env.config
RABBITMQ_NODE_IP=$(ip addr show dev ${rabbit_bind_nic} scope global | grep dynamic| sed -e 's#.*inet ##g' -e 's#/.*##g')
RABBITMQ_NODE_PORT=5672
EOF

if [[ $ha == "y" ]] ; then
  systemctl stop  rabbitmq-server.service
else
  # Start and enable rabbitmq
  systemctl start rabbitmq-server.service
fi

##### ADD CHECK TO VALIDATE RABBIT IS UP PRIOR TO MOVING FORWARD?

# NOTE - Chapter 2 of the CL315 training course on rabbit has good way to test functionality

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


