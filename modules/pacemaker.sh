#!/bin/bash
##########################################################################
# Module:	pacemaker
# Description:	Install Pacemaker and initialize a cluster
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

### NEED $controller_hosts, cluster name, pw AS AN INPUT TO CALLING THIS SCRIPT 
### (SO IT CAN INITIALIZE SEVERAL DIFFERENT CLUSTERS)

# Open firewall ports for pacemaker
iptables -I INPUT -p udp -m state --state NEW -m multiport --dports 5404,5405 -m comment --comment "corosync incoming" -j ACCEPT
iptables -I INPUT -p tcp -m state --state NEW -m multiport --dports 2224 -m comment --comment "pcsd incoming" -j ACCEPT
iptables -I INPUT -p tcp -m state --state NEW -m multiport --dports 3121 -m comment --comment "pacemaker-remote incoming" -j ACCEPT
service iptables save; service iptables restart

yum install -y pacemaker pcs cman resource-agents fence-agents
systemctl start pcsd; systemctl enable pcsd
echo ${pcs_cluster_pw} | passwd --stdin hacluster


  pcs cluster auth $controller_hosts -u hacluster -p ${pcs_cluster_pw} --force
  sleep 3
  pcs cluster setup --name ${pcs_cluster_name} $CTRL1 $CTRL2 $CTRL3 --force
  sleep 3

  pcs cluster enable --all
  sleep 3
  pcs cluster start  --all
  sleep 3

  pcs status

  # Disable quorum until we get fencing working
  sleep 15
  pcs property set no-quorum-policy=ignore


