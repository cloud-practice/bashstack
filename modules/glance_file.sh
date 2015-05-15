#!/bin/bash
##########################################################################
# Module:	glance_file
# Description:	Configure Glance for file backend
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# Change ownership on /etc/glance
chown glance:root /etc/glance
chmod 770 /etc/glance

# Create Glance file backed directories 
mkdir -p /var/lib/glance/images
chown glance:glance /var/lib/glance/images

if [[ $ha == "y" ]]; then
  echo "HA for file-backed glance is not supported by this tool"  
  echo "Options include active/passive HA"
  echo "Or rsync between all standalone glance file systems" 
  echo "Or drbd"   
  exit 1
fi
