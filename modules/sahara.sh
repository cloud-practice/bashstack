#!/bin/bash
##########################################################################
# Module:	sahara
# Description:	Install Sahara Data Processing 
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

# Install packages 
yum -y install openstack-sahara openstack-sahara-doc python-django-sahara python-saharaclient

# Config DB Connection
openstack-config --set /etc/sahara/sahara.conf database connection mysql://sahara:{$sahara_db_pw}@${mariadb_ip}/sahara

# Create the sahara database and populate it
if [ ! -f /root/.my.cnf ] ; then    # Need password-less mysql access
  echo "ERROR - /root/.my.cnf doesn't exist" 
  exit 1
fi
mysql -u root << EOF
CREATE DATABASE sahara;
GRANT ALL ON sahara.* TO 'sahara'@'%' IDENTIFIED BY '${sahara_pw}';
GRANT ALL ON sahara.* TO 'sahara'@'localhost' IDENTIFIED BY '${sahara_pw}';
FLUSH PRIVILEGES;
quit
EOF
sahara-db-manage --config-file /etc/sahara/sahara.conf upgrade head

# Configure Sahara to authenticate to Keystone
source ~/keystonerc_admin
keystone user-create --name sahara --pass ${sahara_pw}
keystone user-role-add --user sahara --role admin --tenant services
keystone service-create --name sahara --type data_processing --description "Sahara Data Processing"
keystone endpoint-create --name sahara --type data_processing --description "Sahara Data Processing" --publicurl "http://${sahara_ip_public}:8636/v1.1/%(tenant_id)s" --adminurl "http://${sahara_ip_admin}:8636/v1.1/%(tenant_id)s" --internalurl "http://${sahara_ip_internal}:8636/v1.1/%(tenant_id)s"

# Configure Sahara API to auth through keystone
openstack-config --set /etc/sahara/sahara.conf DEFAULT os_auth_host ${keystone_ip}
openstack-config --set /etc/sahara/sahara.conf DEFAULT os_auth_port 35357
openstack-config --set /etc/sahara/sahara.conf DEFAULT os_admin_username sahara
openstack-config --set /etc/sahara/sahara.conf DEFAULT os_admin_tenant_name services
openstack-config --set /etc/sahara/sahara.conf DEFAULT os_admin_password ${sahara_pw}

# iptables rules for Sahara
iptables -I INPUT -p tcp -m multiport --dports 8386 -m comment --comment "Sahara incoming" -j ACCEPT
service iptables save; service iptables restart

# Configure and Launch the Sahara service
  # If Neutron: 
openstack-config --set /etc/sahara/sahara.conf DEFAULT use_neutron true

# Setup Logging 
openstack-config --set /etc/sahara/sahara.conf DEFAULT log_dir /var/log/sahara
openstack-config --set /etc/sahara/sahara.conf DEFAULT use_syslog False

# Start and Enable the API service
systemctl enable openstack-sahara-api
systemctl start openstack-sahara-api

# Add the Sahara UI to the dashboard (HORIZON_CONFIG and INSTALLED_APPS)
cp /usr/share/openstack-dashboard/openstack_dashboard/settings.py /usr/share/openstack-dashboard/openstack_dashboard/settings.py.b4sahara

vi /usr/share/openstack-dashboard/openstack_dashboard/settings.py

HORIZON_CONFIG = {
    'dashboards': ('project', 'admin', 'settings', ..., 'sahara',),

INSTALLED_APPS = [

    ' saharadashboard',
...

cp /etc/openstack-dashboard/local_settings /etc/openstack-dashboard/local_settings.backup
vi /etc/openstack-dashboard/local_settings
SAHARA_USE_NEUTRON = True
SAHARA_URL = 'http://${sahara_ip}:8386/v1.1'

# Restart Apache
systemctl restart httpd

#(Bug 1097869 – Sahara dashboard does not show tabs - planned resolution Sep 23 2014)  

### Verify???? 

### Do we want to walk through that process?  I think yes, but lets wait...



