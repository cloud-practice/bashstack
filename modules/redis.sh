#!/bin/bash
##########################################################################
# Module:	redis.sh
# Description:	Configure Redis
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

if [[ $ha == "y" ]]; then
  yum -y install redis

  # Firewall rules for redis
  if [[ $firewall == "firewalld" ]] ; then
    firewall-cmd --add-port=6379/tcp
    firewall-cmd --add-port=6379/tcp --permanent
    firewall-cmd --add-port=26379/tcp
    firewall-cmd --add-port=26379/tcp --permanent
  elif  [[ $firewall == "iptables" ]] ; then
    iptables -I INPUT -p tcp -m multiport --dports 6379 -m comment --comment "redis incoming" -j ACCEPT
    iptables -I INPUT -p tcp -m multiport --dports 26379 -m comment --comment "redis sentinel incoming" -j ACCEPT
    service iptables save; service iptables restart
  else
    echo "No firewall rules created as firewalld and iptables are inactive"
  fi

  if [[ $ha_type == "pacemaker" ]]; then
    # have redis listen on all IPs
    sed -i "s/\s*bind \(.*\)$/#bind \1/" /etc/redis.conf

    if [[ $(hostname -s) == $redis_bootstrap_node ]]; then
      pcs resource create redis redis wait_last_known_master=true --master meta notify=true ordered=true interleave=true
      pcs resource create vip-redis IPaddr2 ip=${redis_ip}
    fi
    
  elif [[ $ha_type == "keepalived" ]]; then
    if [[ $(hostname -s) == $redis_bootstrap_node ]]; then
      redis_bind_ip=$(ip addr show dev ${redis_bind_nic} scope global | grep dynamic| sed -e 's#.*inet ##g' -e 's#/.*##g')
      sed --in-place "s/bind 127.0.0.1/bind 127.0.0.1 ${redis_bind_ip}/" /etc/redis.conf
    else
      redis_bind_ip=$(ip addr show dev ${redis_bind_nic} scope global | grep dynamic| sed -e 's#.*inet ##g' -e 's#/.*##g')
      sed --in-place "s/bind 127.0.0.1/bind 127.0.0.1 ${redis_bind_ip}/" /etc/redis.conf
      echo slaveof ''${redis_bootstrap_ip}'' 6379 >> /etc/redis.conf 
    fi

    cat > /etc/redis-sentinel.conf << EOF
sentinel monitor mymaster ${redis_bootstrap_ip} 6379 2
sentinel down-after-milliseconds mymaster 30000
sentinel failover-timeout mymaster 180000
sentinel parallel-syncs mymaster 1
min-slaves-to-write 1
min-slaves-max-lag 10
logfile /var/log/redis/sentinel.log
EOF

    systemctl enable redis
    systemctl start redis
    systemctl enable redis-sentinel
    systemctl start redis-sentinel

  else
    echo "HA Type not specified"
fi

# Non-HA does not use Redis
