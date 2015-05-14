#!/bin/bash
##########################################################################
# Module:	memcache_pcmk
# Description:	Create pacemaker resource after memcache setup
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

if [[ $ha == "y" ]]; then
  if [[ $ha_type == "pacemaker" ]] ; then
     pcs resource create memcached systemd:memcached --clone
  fi
fi 


