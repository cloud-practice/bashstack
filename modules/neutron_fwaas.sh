#!/bin/bash
##########################################################################
# Module:	neutron_fwaas
# Description:	Install Neutron Firewall as a Service
##########################################################################
# Configure Neutron to auth through keystone

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

exit 1
