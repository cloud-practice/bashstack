#!/bin/bash
##########################################################################
# Module:	pacemaker_fencing_ipmi
# Description:	Setup fence_ipmi fencing devices
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

for host in ${fence_hosts}
do
  node=$(echo $host | awk -F ":" '{print $1}')
  fence_ip=$(echo $host | awk -F ":" '{print $2}')
  ssh $node 'pcs stonith create fence_${node} fence_ipmilan params login="${fence_user}" passwd="${fence_pw}" action="reboot" ipaddr="${fence_ip}" lanplus="" verbose="" pcmk_host_list="${node}" delay=15 op monitor interval=60s'
done

