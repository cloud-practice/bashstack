#!/bin/bash
##########################################################################
# Module:       cinder_test
# Description:  Basic Cinder Validation
##########################################################################

source ~/keystonerc_admin
cinder list
cinder create --display-name testvol 1
cinder show testvol
cinder delete testvol

#### Would be good to add test of attaching / detaching on compute nodes

