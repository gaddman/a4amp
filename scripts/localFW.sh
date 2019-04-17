#!/usr/bin/env bash
# Shortcut to the localFW Ansible playbook, with a few additions to make it easier

show_help() {
        echo "Apply firewall to local host"
        }

if [ "$1" == "-h" ] ; then
        show_help
        exit
fi

# Get playbook filename
# This file should be in <ampDir>/scripts, playbook in <ampDir>/ansible
FILE=$(readlink -f "$0")
DIRECTORY=$(dirname $FILE)
PLAYBOOK=$(dirname $DIRECTORY)/ansible/localFW.yml

ansible-playbook $PLAYBOOK --ask-become-pass
