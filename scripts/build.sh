#!/usr/bin/env bash
# Shortcut to the probe building Ansible playbook, with a few additions to make it easier for a brand new probe
# Chris Gadd
# 2017-05-01

show_help() {
    echo "Build a probe"
    echo -e "\tUsage: `basename $0` [comma separated list of probeids]"
    echo -e "\teg `basename $0` 810,811"
}

if [ "$1" == "-h" ] || [ -z "$1" ]; then
    show_help
    exit
fi


# Get playbook filename
# This file should be in <ampDir>/scripts, playbook in <ampDir>/ansible
FILE=$(readlink -f "$0")
DIRECTORY=$(dirname $FILE)
PLAYBOOK=$(dirname $DIRECTORY)/ansible/build.yml

# Update probelist first
$DIRECTORY/probes.py -u

# check probes are in the probelist
for probe in $(echo "$1" | sed 's/,/ /g'); do
    if ! grep -Fq "$probe" /etc/ansible/hosts; then
        echo "Error: Probe $probe is not in the Ansible inventory, have you added it to the AMP site list and either the 'All probes' mesh or one of the 'Endpoints' meshes?"
        exit
    fi
done

echo "Enter the probe's current password at the first prompt, then hit Enter at the next prompt"
export ANSIBLE_HOST_KEY_CHECKING=False; ansible-playbook $PLAYBOOK --limit=$1 --ask-pass --ask-become-pass --extra-vars rotateSSH=true --timeout=60
# long timeout because after changing the hostname sudo commands don't work nicely (until rebooted)
