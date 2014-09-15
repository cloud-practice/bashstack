#!/bin/bash
##########################################################################
# Module:	keepalived
# Description:	Install Keepalived to handle virtual IP failover.
#		This should be co-located on your HAproxy servers
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi


exit 1
# This is just here for an example at this time... 

# Add this to /etc/keepalived/keepalived.conf on each load balancer
vrrp_script haproxy-check {
    script "killall -0 haproxy"
    interval 2
    weight 10
}

vrrp_instance openstack-vip {
    state BACKUP
    priority 102
    interface eth0
    virtual_router_id 47
    advert_int 3

    virtual_ipaddress {
        10.15.85.31
    }

    track_script {
	haproxy-check
    }
}

# NOTE priority should be different for each node.  
# Example: 102, 132, 162.  

systemctl enable keepalived
systemctl start keepalived
