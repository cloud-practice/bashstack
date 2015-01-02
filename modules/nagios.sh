#!/bin/bash
##########################################################################
# Module:	nagios
# Description:	Install Nagios Monitoring
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# TO DO: 
# - Figure out HA options
# - Setup synthetic monitors for all services
# - Add CPU/mem/disk/net capacity monitors
# - Add pacemaker monitoring
# - Add haproxy monitoring 
# - Break out client setup from master setup 


yum -y install nagios nagios-devel nagios-plugins* gd gd-devel php gcc glibc glibc-common openssl

### NOTE - You might need the optional rpms repo

# Install the NRPE (Nagios Remote Plugin Executor) Addon
# This MUST be installed on each remote machine!
yum install -y nrpe nagios-plugins* openssl
## plugins will be installed to /usr/lib64/nagios/plugins

# Configure HTTPD for Nagios
### Note - default password is nagiosadmin/nagiosadmin

# To change the default password:
htpasswd -c /etc/nagios/passwd nagiosadmin
# To create a new user
# htpasswd /etc/nagios/passwd newUserName

# Update the nagiosadmin contact in /etc/nagios/objects/contacts.cfg
define contact{
        contact_name    nagiosadmin             ; Short name of user
        email           yourName@example.com    ; *****CHANGE THIS******
}

# Verify the basic configuration 
nagios -v /etc/nagios/nagios.cfg

# Enable Nagios and restart httpd 
systemctl enable nagios
systemctl restart httpd
systemctl start nagios

#### NOTE - Firewall rules should already be open... 

# Verify you can connect: 
wget http://nagiosHostURL/nagios

# /etc/nagios/objects/localhost.cfg is used to define services for basic local stats.  Additional service files can be used if defined in /etc/nagios/nagios.cfg

# Configure Nagios to monitor an OpenStack Service
cp /root/keystonerc_admin /etc/nagios
  ########## Cinder ##########
    # Create monitor & ensure it's executable
cat << EOF >> /usr/lib64/nagios/plugins/cinder-list
#!/bin/env bash

. /etc/nagios/keystonerc_admin

data=$(cinder list --all-tenants 2>&1)
rv=$?

if [ "$rv" != "0" ] ; then
    echo $data
    exit $rv
fi

echo "$data" | grep -v -e '--------' -e ' Status ' | wc -l
EOF
chmod u+x /usr/lib64/nagios/plugins/cinder-list
    # Add monitor to the commands config
cat << EOF >> /etc/nagios/objects/commands.cfg
define command {
        command_line                    /usr/lib64/nagios/plugins/cinder-list
        command_name                    cinder-list
}
EOF
    # Define the service for each new item -- NOTE, REPLACE localURL
cat << EOF >> /etc/nagios/objects/localhost.cfg
define service {
        check_command   cinder-list
        host_name       localURL
        name            cinder-list
        normal_check_interval   5
        service_description     Number of Cinder Volumes
        use             generic-service
}
EOF

  ########## Glance ##########
    # Create monitor & ensure it's executable
cat << EOF >> /usr/lib64/nagios/plugins/glance-index
#!/bin/env bash

. /etc/nagios/keystonerc_admin

data=$(glance image-list --all-tenants 2>&1)
rv=$?

if [ "$rv" != "0" ] ; then
    echo $data
    exit $rv
fi

echo "$data" | grep -v -e "^ID " -e "---------------" | wc -l
EOF
chmod u+x /usr/lib64/nagios/plugins/glance-index
    # Add monitor to the commands config
cat << EOF >> /etc/nagios/objects/commands.cfg
define command {
        command_line                    /usr/lib64/nagios/plugins/glance-index
        command_name                    glance-image-list
}
EOF
    # Define the service for each new item -- NOTE, REPLACE localURL
cat << EOF >> /etc/nagios/objects/localhost.cfg
define service {
        check_command   glance-image-list
        host_name       localURL
        name            glance-image-list
        normal_check_interval   5
        service_description     Number of Glance Images
        use             generic-service
}
EOF


  ########## Keystone ##########
    # Create monitor & ensure it's executable
cat << EOF >> /usr/lib64/nagios/plugins/keystone-user-list
#!/bin/env bash

. /etc/nagios/keystonerc_admin

data=$(keystone user-list 2>&1)
rv=$?

if [ "$rv" != "0" ] ; then
    echo $data
    exit $rv
fi

echo "$data" | grep -v -e "   id    " -e "---------------"  | wc -l
EOF
chmod u+x /usr/lib64/nagios/plugins/keystone-user-list
    # Add monitor to the commands config
cat << EOF >> /etc/nagios/objects/commands.cfg
define command {
        command_line                    /usr/lib64/nagios/plugins/keystone-user-list
        command_name                    keystone-user-list
}
EOF
    # Define the service for each new item -- NOTE, REPLACE localURL
cat << EOF >> /etc/nagios/objects/localhost.cfg
define service {
        check_command   keystone-user-list
        host_name       localURL
        name            keystone-user-list
        normal_check_interval   5
        service_description     Number of Keystone Users
        use             generic-service
}
EOF


  ########## Nova ##########
    # Create monitor & ensure it's executable
cat << EOF >> /usr/lib64/nagios/plugins/nova-list
#!/bin/env bash

. /etc/nagios/keystonerc_admin

data=$(nova list  2>&1)
rv=$?

if [ "$rv" != "0" ] ; then
    echo $data
    exit $rv
fi

echo "$data" | grep -v -e '--------' -e '| Status |' -e '^$' | wc -l
EOF
chmod u+x /usr/lib64/nagios/plugins/nova-list
    # Add monitor to the commands config
cat << EOF >> /etc/nagios/objects/commands.cfg
define command {
        command_line                    /usr/lib64/nagios/plugins/nova-list
        command_name                    nova-list
}
EOF
    # Define the service for each new item -- NOTE, REPLACE localURL
cat << EOF >> /etc/nagios/objects/localhost.cfg
define service {
        check_command   nova-list
        host_name       localURL
        name            nova-list
        normal_check_interval   5
        service_description     Number of Nova VM Instances
        use             generic-service
}
EOF

  ########## Swift ##########
    # Create monitor & ensure it's executable
cat << EOF >> /usr/lib64/nagios/plugins/swift-list
#!/bin/env bash

. /etc/nagios/keystonerc_admin

data=$(swift list 2>&1)
rv=$?

if [ "$rv" != "0" ] ; then
    echo $data
    exit $rv
fi

echo "$data" |wc -l
EOF
chmod u+x /usr/lib64/nagios/plugins/swift-list
    # Add monitor to the commands config
cat << EOF >> /etc/nagios/objects/commands.cfg
define command {
        command_line                    /usr/lib64/nagios/plugins/swift-list
        command_name                    swift-list
}
EOF
    # Define the service for each new item -- NOTE, REPLACE localURL
cat << EOF >> /etc/nagios/objects/localhost.cfg
define service {
        check_command   swift-list
        host_name       localURL
        name            swift-list
        normal_check_interval   5
        service_description     Number of Nova VM Instances
        use             generic-service
}
EOF

systemctl restart nagios

### NOTE - Need to build more capability here.  This is what packstack provides
### Maybe look here: http://openstack.prov12n.com/monitoring-openstack-nagios-3/
### Or MONaaS blueprint: https://wiki.openstack.org/wiki/MONaaS

### http://blog.zhaw.ch/icclab/nagios-ceilometer-integration-new-plugin-available/

# Configure NRPE monitoring on a remote machine 
# In /etc/nagios/nrpe.cfg add the IP address of your central nagios server
allowed_hosts=127.0.0.1, NagiosCentralServerIP

# Edit /etc/nagios/nrpe.cfg to add any services to be monitored
# I think these are default: 
command[check_users]=/usr/lib64/nagios/plugins/check_users -w 5 -c 10
command[check_load]=/usr/lib64/nagios/plugins/check_load -w 15,10,5 -c 30,25,20
command[check_hda1]=/usr/lib64/nagios/plugins/check_disk -w 20% -c 10% -p /dev/hda1
command[check_zombie_procs]=/usr/lib64/nagios/plugins/check_procs -w 5 -c 10 -s Z
command[check_total_procs]=/usr/lib64/nagios/plugins/check_procs -w 150 -c 200

# An example of monitoring an OpenStack service: 
command[keystone]=/usr/lib64/nagios/plugins/check_procs -c 1: -w 3: -C keystone-all

 ##### NEED TO BUILD OUT MORE MONITORING HERE #####

# Configure iptables to allow nrpe traffic
iptables -I INPUT -p tcp -m multiport --dports 5666 -m comment --comment "Nagios nrpe incoming" -j ACCEPT
service iptables save; service iptables restart
  ## Guessing this needs to be on each Nagios client... 

systemctl start nrpe

# Create Host Definitions
### You must make remote hosts known to the central Nagios server
   # Note in packstack this is actually called /etc/nagios/objects/host.cfg
cat << EOF >> /etc/nagios/objects/hosts.cfg
define host{
        use linux-server
        host_name remoteHostName
        alias remoteHostAlias
        address remoteIPAddress
}
EOF
# Add this file to the main configuration
echo "cfg_file=/etc/nagios/objects/hosts.cfg" >> /etc/nagios/nagios.cfg

# Create Service Definitions for Remote Services
  # Add a command for nrpe to execute remotely
cat << EOF >> /etc/nagios/objects/commands.cfg
define command{
        command_line    /usr/lib64/nagios/plugins/check_nrpe -H $HOSTADDRESS$ -c $ARG1$
        command_name    check_nrpe
}
EOF
# Create a service in /etc/nagios/objects/services.cfg
cat << EOF >> /etc/nagios/objects/services.cfg
##Basic remote checks#############
##Remember that remoteHostName is defined in the hosts.cfg file.
define service{
        use generic-service
        host_name remoteHostName
        service_description PING
        check_command check_ping!100.0,20%!500.0,60%
}
define service{
        use generic-service
        host_name remoteHostName
        service_description Load Average
        check_command check_nrpe!check_load
}
##OpenStack Service Checks#######
define service{
        use generic-service
        host_name remoteHostName
        service_description Identity Service
        check_command check_nrpe!keystone
}
EOF
##### NEED TO BUILD OUT THE SERVICES CHECKS HERE TOO
echo "cfg_file=/etc/nagios/objects/services.cfg" >> /etc/nagios/nagios.cfg
### NOTE: Packstack uses /etc/nagios/nagios_service.cfg, /etc/nagios/nagios_host.cfg, and /etc/nagios/nagios_command.cfg

systemctl restart nagios

# Verify the Nagios configuration:
nagios -v /etc/nagios/nagios.cfg
wget http://nagiosURL/nagios


