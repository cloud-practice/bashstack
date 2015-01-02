#!/bin/bash
##########################################################################
# Module:	prerequisites
# Description:	This module prepares a node for an OpenStack installation.  
#		It assumes a minimal install already exists
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi 

#### NOTE - YOU MUST SETUP YUM REPOSITORIES FIRST! 
### This needs some intelligence for yum vs. RHN
./prerequisites_yumrepo.sh

## ADD SECTION TO CHECK HOST NAME RESOLUTION (OR CREATE HOSTS) 


# Disable Network Manager and Enable Network Service
systemctl status NetworkManager.service | grep Active:
systemctl stop NetworkManager.service
systemctl disable NetworkManager.service

systemctl start network.service
systemctl enable network.service

In each /etc/sysconfig/network-scripts file add
NM_CONTROLLED=no
ONBOOT=yes

# Install iptables services 
yum -y install iptables iptables-services

# Disable firewalld and enable iptables
service firewalld stop
service iptables start
chkconfig firewalld off
chkconfig iptables on

# Setup and start NTP 
yum -y install ntp
   ##### NOTE - Set ntp servers from answers file #####
systemctl enable ntpd
systemctl start ntpd

# If compute node, verify hardware support and kvm
# Confirm Hardware Support
grep -E 'svm|vmx' /proc/cpuinfo

# Confirm kvm module
lsmod | grep kvm

# Install some base packages that are useful for troubleshooting 
#### These really should be optional
yum -y install bind-utils net-tools wget telnet

# Install OpenStack selinux 
yum -y install openstack-selinux

# Update all packages 
yum -y update 

echo "yum -y update was executed.  You may want to reboot if a kernel changed"
