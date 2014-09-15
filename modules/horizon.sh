#!/bin/bash
##########################################################################
# Module:	horizon
# Description:	Install Horizon Dashboard
##########################################################################
ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi


# Install packages
yum -y install httpd mod_wsgi mod_ssl memcached python-memcached openstack-dashboard

# Enable and Start Apache 
systemctl start httpd
systemctl enable httpd
service --status-all | grep httpd

# Configure the Dashboard
  vi /etc/openstack-dashboard/local_settings
 1) Cache Backend
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
CACHES = {
    'default': {
    'BACKEND' : 'django.core.cache.backends.memcached.MemcachedCache',
    'LOCATION' : 'memcacheURL:port',
  }
}

# port should be defined in /etc/sysconfig/memcached
 #2) Dashboard Host (Really?  I dont recall this in Icehouse!)
 #OPENSTACK_HOST="127.0.0.1" # -> Verified it's not in my packstack builds...

 3) Time Zone
 TIME_ZONE="UTC"

# Likely want to edit ALLOWED_HOSTS as well!!!

systemctl restart httpd

# Configure dashboard to use https:

vi /etc/openstack-dashboard/local_settings
  SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTOCOL', 'https')
  CSRF_COOKIE_SECURE = True
  SESSION_COOKIE_SECURE = True
vi /etc/httpd/conf/httpd.conf
  NameVirtualHost *:443
vi /etc/httpd/conf.d/openstack-dashboard.conf
 sed s/
WSGIScriptAlias /dashboard /usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi
Alias /static /usr/share/openstack-dashboard/static/
<Directory /usr/share/openstack-dashboard/openstack_dashboard/wsgi>
<IfModule mod_deflate.c>
SetOutputFilter DEFLATE
<IfModule mod_headers.c>
# Make sure proxies donâ<200b><200b> t deliver the wrong content
Header append Vary User-Agent env=!dont-vary
</IfModule>
</IfModule>
Order allow,deny
Allow from all
</Directory>
***************************substitute with: *********************************

***************************substitute with: *********************************
<VirtualHost *:80>
ServerName openstack.example.com
RedirectPermanent / https://openstack.example.com/
</VirtualHost>
<VirtualHost *:443>
ServerName openstack.example.com
SSLEngine On
SSLCertificateFile /etc/httpd/SSL/openstack.example.com.crt
SSLCACertificateFile /etc/httpd/SSL/openstack.example.com.crt
SSLCertificateKeyFile /etc/httpd/SSL/openstack.example.com.key
SetEnvIf User-Agent ".*MSIE.*" nokeepalive ssl-unclean-shutdown
WSGIScriptAlias / /usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi
WSGIDaemonProcess horizon user=apache group=apache processes=3 threads=10
RedirectPermanent /dashboard https://openstack.example.com
Alias /static /usr/share/openstack-dashboard/static/
<Directory /usr/share/openstack-dashboard/openstack_dashboard/wsgi>
Order allow,deny
Allow from all
</Directory>
</VirtualHost>

# Restart httpd and memcached
systemctl httpd restart
systemctl memcached restart

# Create a member role
source ~/keystonerc_admin
keystone role-create --name Member

# Configure SELinux
getenforce
setsebool -P httpd_can_network_connect on

# Configure iptables for dashboard
iptables -I INPUT -p tcp -m multiport --dports 80,443 -m comment --comment "httpd horizon dashboard incoming" -j ACCEPT
service iptables save; service iptables restart


# Session Storage Options  (in /etc/openstack-dashboard/local_settings)
### Local Memcache ###
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
        CACHES = {
                'default': {
                'BACKEND': 'django.core.cache.backends.locmem.LocMemCache'
        }
}

### Database Session Storage ### 
if [ ! -f /root/.my.cnf ] ; then    # Need password-less mysql access
  echo "ERROR - /root/.my.cnf doesn't exist" 
  exit 1
fi
mysql -u root << EOF
CREATE DATABASE dash;
GRANT ALL ON dash.* TO 'dash'@'%' IDENTIFIED BY '${horizon_db_pw}';
GRANT ALL ON dash.* TO 'dash'@'localhost' IDENTIFIED BY '${horizon_db_pw}';
FLUSH PRIVILEGES;
quit
EOF
# in local_settings
SESSION_ENGINE = 'django.contrib.sessions.backends.cached_db'
        DATABASES = {
                'default': {
                # Database configuration here
                'ENGINE': 'django.db.backends.mysql',
                'NAME': 'dash',
                'USER': 'dash',
                'PASSWORD': '${horizon_db_pw}',
                'HOST': 'HOST',
                'default-character-set': 'utf8'
        }
}

cd /usr/share/openstack-dashboard
python manage.py syncdb

## NOTE - You will be asked to create an admin account.  This is not required.  
## No fixtures found is NOT an error.  This is expected 
systemctl restart httpd
systemctl restart openstack-nova-api

### Cached DB Session Storage ### 
### Mitigated performance impact by using DB & Caching
### Setup both DB and Cache as discussed above
SESSION_ENGINE = "django.contrib.sessions.backends.cached_db"
### makes me wonder if cached_db is wrong above... 

# If you want to use cookies: 
SESSION_ENGINE = "django.contrib.sessions.backends.signed_cookies"
django-admin.py startproject

# Validate 
wget https://HOSTNAME/dashboard/
wget http://HOSTNAME/dashboard/


