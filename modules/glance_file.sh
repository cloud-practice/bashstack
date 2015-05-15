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

### Make certain no HA. (Active/Passive HA is possible ... )
