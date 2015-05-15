#!/bin/bash
##########################################################################
# Module:	glance_nfs
# Description:	Configure Glance for NFS backend
##########################################################################
ANSWERS=/root/bashstack/answers.txt

# TODO: Implement this section! 

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# Create Glance file backed directories 
mkdir -p /var/lib/glance/images
chown glance:glance /var/lib/glance/images


