#!/bin/bash
##########################################################################
# Module:	memcache
# Description:	Install memcached
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

yum -y install memcached

# Firewall rules for memcached
if [[ $(systemctl is-active firewalld) == "active" ]] ; then
  firewall-cmd --add-port=11211/tcp
  firewall-cmd --add-port=11211/tcp --permanent
elif  [[ $(systemctl is-active iptables) == "active" ]] ; then
  iptables -I INPUT -p tcp -m multiport --dports 11211 -m comment --comment "memcached incoming" -j ACCEPT
  service iptables save; service iptables restart
else
  echo "No firewall rules created as firewalld and iptables are inactive"
fi

if [[ $ha == "y" ]]; then
  if [[ $ha_type == "pacemaker" ]] ; then
     systemctl disable memcached
  elif [[ $ha_type == "keepalived" ]] ; then
     systemctl enable memcached 
     systemctl start memcached
  else
     echo "No HA Type specified"
  fi
elif [[ $ha == "n" ]]; then
  systemctl enable memcached
  systemctl start memcached
else
  echo "No HA specified"
fi


