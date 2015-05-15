#!/bin/bash
##########################################################################
# Module:	glance_ceph
# Description:	Configure Glance for Ceph RBD Backend
##########################################################################
ANSWERS=/root/bashstack/answers.txt

# TODO: Implement this section

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi


