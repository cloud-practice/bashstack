#!/bin/bash
##########################################################################
# Module:	neutron
# Description:	Install Neutron VPN as a Service
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

