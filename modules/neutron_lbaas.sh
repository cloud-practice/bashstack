#!/bin/bash
##########################################################################
# Module:	neutron_lbaas
# Description:	Install Neutron Load Balancer as a Service
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

exit 1
