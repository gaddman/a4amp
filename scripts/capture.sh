#!/usr/bin/env bash
# Run tcpdump on probes and upload back to server

show_help() {
        echo "Run tcpdump on endpoints/probes and upload back to server"
        echo -e "\tUsage: `basename $0` [comma separated list of probeids or groups]"
        echo -e "\tgroup may be 'all', 'endpoints' or 'probes', or give a specific host"
        echo -e "\tFor example: '`basename $0` endpoints,880' will capture on all of the endpoint servers and probe 880"
        }

if [ "$1" == "-h" ] || [ -z "$1" ]; then
        show_help
        exit
fi

# Get playbook filename
# This file should be in <ampDir>/scripts, playbook in <ampDir>/ansible
FILE=$(readlink -f "$0")
DIRECTORY=$(dirname $FILE)
PLAYBOOK=$(dirname $DIRECTORY)/ansible/tcpdump.yml

ansible-playbook $PLAYBOOK --limit=$1
