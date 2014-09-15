#!/bin/bash
##########################################################################
# Module:	rsyslog_client
# Description:	Setup agent for rsyslog clients
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

exit 1

yum -y install rsyslog

vi /etc/rsyslog.conf
*.*     @YOURSERVERADDRESS:YOURSERVERPORT
### NOTE '@' specifies UDP.  @@ would be used for TCP

systemctl enable rsyslog
systemctl restart rsyslog

