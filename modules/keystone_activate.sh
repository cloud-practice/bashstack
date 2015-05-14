#!/bin/bash
##########################################################################
# Module:	keystone_activate
# Description:	This is run after keystone is installed on all servers to 
#		get it running
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

if [[ $ha == "y" ]]; then
  if [[ $(hostname -s) == $keystone_bootstrap_node ]]; then
    # Create and distribute PKI, manage DB
    keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
    chown -R keystone:keystone /var/log/keystone /etc/keystone/ssl/
    su keystone -s /bin/sh -c "keystone-manage db_sync"
    cd /etc/keystone/ssl
    tar cvfz /tmp/keystone_ssl.tgz *
    # Copy pki to others
    for node in $keystone_nodes
    do
      if [[ $node != $(hostname -s) ]]; then
        scp /tmp/keystone_ssl.tgz $node:/tmp
      fi
    done
  else
    # Restore PKI setup from 1st node
    mkdir -p /etc/keystone/ssl
    cd /etc/keystone/ssl
    tar xvfz /tmp/keystone_ssl.tgz 
    chown -R keystone:keystone /var/log/keystone /etc/keystone/ssl/
    restorecon -Rv /etc/keystone/ssl
  fi 

  if [[ $ha_type == "pacemaker" ]]; then
    systemctl disable openstack-keystone
   
    if [[ $(hostname -s) == $keystone_bootstrap_node ]]; then
      pcs resource create keystone systemd:openstack-keystone --clone
  
      # Add pcs constraints for colocated resources 
      
      pcs resource show lb-haproxy-clone &>/dev/null 
      if [[ $? == 0 ]]; then 
        pcs constraint order start lb-haproxy-clone then keystone-clone
      fi
      pcs resource show galera-master &>/dev/null 
      if [[ $? == 0 ]]; then
        pcs constraint order promote galera-master then keystone-clone
      fi
      pcs resource show rabbitmq-server-clone &>/dev/null
      if [[ $? == 0 ]]; then
        pcs constraint order start rabbitmq-server-clone then keystone-clone
      fi
      pcs resource show memcached-clone &>/dev/null
      if [[ $? == 0 ]]; then 
        pcs constraint order start memcached-clone then keystone-clone
      fi

    fi
  elif [[ $ha_type == "keepalived" ]]; then
    systemctl enable openstack-keystone
    systemctl start openstack-keystone
  else
    echo "No HA Type specified"
    exit 1
  fi
elif [[ $ha == "n" ]]; then
  # Populate database and start keystone
  su keystone -s /bin/sh -c "keystone-manage db_sync"
  systemctl enable openstack-keystone
  systemctl start openstack-keystone
else
  echo "HA not specified."
  exit 1
fi

# Create /root/keystonerc_admin on all nodes
cat << EOF > /root/keystonerc_admin
export OS_USERNAME=admin
export OS_TENANT_NAME=admin
export OS_PASSWORD=${admin_pw}
export OS_AUTH_URL=http://${keystone_ip}:5000/v2.0/
# export OS_REGION_NAME=RegionOne
export PS1='[\u@\h \W(keystone_admin)]\$ '
EOF

