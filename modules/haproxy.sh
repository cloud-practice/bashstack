#!/bin/bash
##########################################################################
# Module:	haproxy
# Description:	Install haproxy Load Balancer
##########################################################################

# TODO: haproxy.cfg


ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

yum -y install haproxy 
echo net.ipv4.ip_nonlocal_bind=1 >> /etc/sysctl.d/haproxy.conf
echo 1 > /proc/sys/net/ipv4/ip_nonlocal_bind
# the keepalive settings must be set in *ALL* hosts interacting with rabbitmq.
cat >/etc/sysctl.d/tcp_keepalive.conf << EOF
net.ipv4.tcp_keepalive_intvl = 1
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_time = 5
EOF
sysctl net.ipv4.tcp_keepalive_intvl=1
sysctl net.ipv4.tcp_keepalive_probes=5
sysctl net.ipv4.tcp_keepalive_time=5



