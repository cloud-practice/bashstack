#!/bin/bash
##########################################################################
# Module:	nova_networking
# Description:	Install Nova Networking 
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

echo "Nova Networking is not supported by this tool..."
exit 1
