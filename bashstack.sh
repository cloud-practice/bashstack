#!/bin/bash
############################################################################
# Name:		bashstack
# Description:	Main Program for Installation of OpenStack
############################################################################

getopt -al -- $@

# --dry-run  - Executes a dry run and outputs every command to be run 
# --dry-run-no-ssh - Same as dry run, but executed locally (needed?) 
# --gen-answer-file (=file) - Creates the answers file
