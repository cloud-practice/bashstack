#!/bin/bash
##########################################################################
# Module:	mariadb
# Description:	Install mariadb on a host
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# Install database server
yum -y install mariadb-galera-server

# Set firewall rule to allow incoming traffic 
iptables -I INPUT -p tcp -m multiport --dports 3306 -m comment --comment "mysql incoming" -j ACCEPT
service iptables save
service iptables restart

# Start and enable MariaDB
systemctl start mariadb.service
systemctl enable mariadb.service

# Set root password for the database
/usr/bin/mysqladmin -u root password "${db_root_pw}"

# Create a .my.cnf file for password-less authentication
cat << EOF >> /root/.my.cnf
[client]
user=root
host=localhost
password=${db_root_pw}
EOF

