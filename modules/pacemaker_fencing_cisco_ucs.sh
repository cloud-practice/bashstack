#!/bin/bash
##########################################################################
# Module:	pacemaker_fencing_cisco_ucs
# Description:	Setup fence_cisco_ucs fencing devices
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

exit 1
# This hasn't been tested as of yet and clearly needs work

export FIRSTHOST=ctlr1
export CTLRLIST="ctlr1 ctlr2 ctlr3"

##
##
##
for i in $CTLRLIST
do
    ssh $i "yum install -y resource-agents fence-agents"
done

##
## Create fencing resources on each controller
##
#pcs stonith list
#pcs stonith describe fence_cisco_ucs


##
## UCS Fencing Example
##

##
## Controller 1
##
#pcs stonith create fence_NODENAME fence_cisco_ucs params login=USERNAME passwd=PASSWORD action=reboot ipaddr=UCS_MANAGER_IPADDR suborg=/org-UCS_ORG/ port=UCS_PROFILE verbose="" ssl="1" ssl_insecure="1" login_timeout=10 pcmk_host_list=NODENAME

##
## Controller 2
##
#pcs stonith create fence_NODENAME fence_cisco_ucs params login=USERNAME passwd=PASSWORD action=reboot ipaddr=UCS_MANAGER_IPADDR suborg=/org-UCS_ORG/ port=UCS_PROFILE verbose="" ssl="1" ssl_insecure="1" login_timeout=10 pcmk_host_list=NODENAME

##
## Controller 3
##
#pcs stonith create fence_NODENAME fence_cisco_ucs params login=USERNAME passwd=PASSWORD action=reboot ipaddr=UCS_MANAGER_IPADDR suborg=/org-UCS_ORG/ port=UCS_PROFILE verbose="" ssl="1" ssl_insecure="1" login_timeout=10 pcmk_host_list=NODENAME

#pcs status

##
##
##
#pcs property set stonith-enabled=true 
#stonith_admin -l
#stonith_admin -reboot=<node>

