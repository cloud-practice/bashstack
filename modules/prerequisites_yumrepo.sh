#!/bin/bash
##########################################################################
# Module:	prerequisites_yumrepo
# Description:	Setup local yum repos for a node
##########################################################################

# Obviously need to update this for changing repo location

cat << EOF >> /etc/yum.repos.d/rhelosp5.repo
[rhel-x86_64-server-7]
name=Red Hat Enterprise Linux $releasever - $basearch
baseurl=http://192.168.122.1/repos/rhel-x86_64-server-7/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

[rhel-x86_64-server-7-ost-5]
name=Red Hat Enterprise Linux OSP 5
baseurl=http://192.168.122.1/repos/rhel-x86_64-server-7-ost-5/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

[rhel-x86_64-server-ha-7]
name=Red Hat Enterprise Linux $releasever - $basearch High Availability
baseurl=http://192.168.122.1/repos/rhel-x86_64-server-ha-7/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

[rhel-x86_64-server-rh-common-7]
name=Red Hat Enterprise Linux $releasever - $basearch Common
baseurl=http://192.168.122.1/repos/rhel-x86_64-server-rh-common-7/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

# I don't believe Optional or Supplementary is needed... 

#[rhel-x86_64-server-optional-7]
#name=Red Hat Enterprise Linux $releasever - $basearch Optional
#baseurl=http://192.168.122.1/repos/rhel-x86_64-server-optional-7/
#enabled=1
#gpgcheck=1
#gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
#
#[rhel-x86_64-server-supplementary-7]
#name=Red Hat Enterprise Linux $releasever - $basearch Supplementary
#baseurl=http://192.168.122.1/repos/rhel-x86_64-server-supplementary-7/
#enabled=1
#gpgcheck=1
#gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

EOF
