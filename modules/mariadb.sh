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

# Drop the test database (if it exists)
mysql -u root -e 'DROP DATABASE IF EXISTS test;'

# Drop all users but root@localhost
## Note there is no drop if exists.  So I'm working around that by granting then removing a user... 
## You can validate users with mysql -u root -e 'select user,host from mysql.user;'
mysql -u root << EOF
GRANT USAGE ON *.* TO ''@'localhost';
DROP USER ''@'localhost';

GRANT USAGE ON *.* TO ''@'$(hostname)';
DROP USER ''@'$(hostname)';

GRANT USAGE ON *.* TO ''@'%';
DROP USER ''@'%';

GRANT USAGE ON *.* TO 'root'@'$(hostname)';
DROP USER 'root'@'$(hostname)';

GRANT USAGE ON *.* TO 'root'@'127.0.0.1';
DROP USER 'root'@'127.0.0.1';

GRANT USAGE ON *.* TO 'root'@'::1';
DROP USER 'root'@'::1';

EOF
