#!/bin/bash
##########################################################################
# Module:	pacemaker_fencing_xvm
# Description:	Setup fence_xvm fencing devices
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

exit 1
# This hasn't been tested and is clearly missing some detail... 
export FIRSTHOST=ctlr1
export CTLRLIST="ctlr1 ctlr2 ctlr3"
export HOST=10.10.0.1

##
## Create fencing resources on each controller
##
#pcs stonith list
#pcs stonith describe fence_xvm

mkdir -p /etc/cluster/
#scp  ${HOST}:/etc/cluster/fence_xvm.* /etc/cluster/

##
## Create the fencing resource
##
pcs stonith create xvmfence fence_xvm pcmk_host_map="ctlr1 ctlr2 ctlr3" key_file=/etc/cluster/fence_xvm.key

pcs status

