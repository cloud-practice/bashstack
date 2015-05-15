#!/bin/bash
##########################################################################
# Module:	mongodb
# Description:	Install MongoDB 
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

yum -y install mongodb mongodb-server

# Firewall rules for MongoDB:
if [[ $firewall == "firewalld" ]] ; then
  firewall-cmd --add-port=27017/tcp
  firewall-cmd --add-port=27017/tcp --permanent
elif  [[ $firewall == "iptables" ]] ; then
  iptables -I INPUT -p tcp -m multiport --dports 27017-m comment --comment "MongoDB incoming" -j ACCEPT
  service iptables save; service iptables restart
else
  echo "No firewall rules created as firewalld and iptables are inactive"
fi


# Set MongoDB config
####echo '"OPTIONS="--smallfiles /etc/mongodb.conf' >> /etc/sysconfig/mongod

if [[ $ha == "y" ]]; then
  # Setup Replication Set
  sed -i \
	-e 's#.*bind_ip.*#bind_ip = 0.0.0.0#g' \
	-e 's/.*replSet.*/replSet = ceilometer/g' \
	-e 's/.*smallfiles.*/smallfiles = true/g' \
	/etc/mongod.conf

  # Start/Stop Mongo (required to bootstrap)
  systemctl start mongodb 
  systemctl stop mongodb

  if [[ $ha_type == "pacemaker" ]]; then
    systemctl disable mongodb
    if [[ $(hostname -s) == "$mongo_bootstrap_node" ]]; then
      pcs resource create mongodb systemd:mongod op start timeout=300s --clone
      pcs resource op add mongodb start timeout=120s
      sleep 20
    fi
  elif [[ $ha_type == "keepalived" ]]; then 
    systemctl enable mongodb
    systemctl start mongodb
  else
     echo "No HA Type specified"
  fi

else
   # No HA - Setup mongo and start
   sed -i \
        -e 's#.*bind_ip.*#bind_ip = 0.0.0.0#g' \
        -e 's/.*smallfiles.*/smallfiles = true/g' \
        /etc/mongod.conf

   # Start/Enable MongoDB
   systemctl enable mongod
   systemctl start mongod
fi


