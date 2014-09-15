#!/bin/bash
##########################################################################
# Module:	rsyslog
# Description:	Install Central Logging
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# TODO: 
# - Logstash/ElasticSearch/Kibana
# - HA for central logging
# - Setup for log management (how much to keep, when to delete)

# Install rsyslog package on Central Server
yum -y install rsyslog

# Configure selinux & iptables to allow rsyslog traffic
yum -y install policycoreutils-python
semanage -a -t syslogd_port_t -p udp 514
-A INPUT -m state --state NEW -m udp -p udp --dport 514 -j ACCEPT

iptables -I INPUT -m state --state NEW -m udp -p udp --dport 512 -m comment --comment "rsyslog incoming" -j ACCEPT
service iptables save; service iptables restart

# Configure for logging 
# Add this line?
vi /etc/rsyslog.conf
$template TmplAuth, "/var/log/%HOSTNAME%/%PROGRAMNAME%.log"
authpriv.*      ?TmplAuth
*.info,mail.none,authpriv.none,cron.none        ?TmplMsg

# Remove the comment for these lines: 
$ModLoad imudp
$UDPServerRun 514

systemctl enable rsyslog
systemctl restart rsyslog


