#!/usr/bin/env bash
# Log probe connections & disconnections, roughly
# Proper way would be rsyslog for the auth events, but that's more intensive than necessary
# Chris Gadd
# 3/09/2017

show_help() {
    echo "Log probe connections & disconnections"
    echo -e "\tUsage: `basename $0`"
}


yaml() {
    python -c "import yaml;print(yaml.load(open('$1'))$2)"
}

# Get config filename
# This file should be in <ampDir>/scripts, config in <ampDir>/ansible/vars
FILE=$(readlink -f "$0")
DIRECTORY=$(dirname $FILE)
CONFIG=$(dirname $DIRECTORY)/ansible/vars/main.yml

# Read config
recipients=$(yaml $CONFIG "['email']['recipients']")
user=$(yaml $CONFIG "['email']['user']")
password=$(yaml $CONFIG "['email']['password']")
server=$(yaml $CONFIG "['email']['server']")
reply=$(yaml $CONFIG "['email']['reply']")

if [ "$1" == "-h" ]; then
    show_help
    exit
fi

newlist="/tmp/activeprobesnew"
oldlist="/tmp/activeprobesold"
logfile="/var/log/probes.log"

# Get latest probe status
$DIRECTORY/probes.py -a | head -n -1 > $newlist

# Use diff to display nicely
timestamp=$(date -Imin)
delta=$(diff --old-line-format="[$timestamp] Disconnected: %L" --new-line-format="[$timestamp] Connected:    %L" --unchanged-line-format="" -N $oldlist $newlist)

# Log and email if there's a change
if [[ ! -z "$delta" ]]; then
    echo "$delta" >> $logfile
    # echo "$delta" | s-nail -r "$reply" -s "Probe (dis)connected" -S smtp="$server" -S smtp-use-starttls -S smtp-auth=login -S smtp-auth-user="$user" -S smtp-auth-password="$password" -S ssl-verify=ignore -S ssl-rand-file=/tmp/mail.rnd "$recipients"
    echo "$delta" | mailx -r "$reply" -s "Probe (dis)connected" "$recipients"
fi

# Update old probestatus
mv $newlist $oldlist
