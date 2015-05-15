#!/bin/bash
##########################################################################
# Module:	randomize_answers
# Description:	Randomize per-deploy answers
##########################################################################

# TODO - This is just a placeholder for things that need to be randomized
#        so that each deployment doesn't have the same keys

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

## Need to verify sed with variables works... 

## NEED TO DO PASSWORDS HERE
keystone_admin_token=$(openssl rand -hex 10)
sed -i -e "s/^keystone_admin_token=.*/keystone_admin_token=$keystone_admin_token/" $ANSWERS

ceilometer_metering_secret=$(openssl rand -hex 10)
sed -i -e "s/^ceilometer_metering_secret=.*/ceilometer_metering_secret=$ceilometer_metering_secret/" $ANSWERS



