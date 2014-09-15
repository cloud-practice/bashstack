#!/bin/bash
##########################################################################
# Module:	memcache
# Description:	Install memcached
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

yum -y install memcached
