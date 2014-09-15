#!/bin/bash
##########################################################################
# Module:	haproxy
# Description:	Install haproxy Load Balancer
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

