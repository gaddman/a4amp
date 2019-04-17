#!/usr/bin/env bash
# Start/stop/restart AMP clients
# Just a shortcut for ad-hoc ansible command

show_help() {
    echo "Start/stop/restart probe"
    echo -e "\tUsage: `basename $0` [probeid or group] [start/stop/restart]"
    echo -e "\tgroup may be 'all', 'endpoints' or 'probes', or give a specific host"
    }

if [ "$2" == "-h" ] || [ -z "$2" ]; then
    show_help
    exit
elif [ "$2" == "start" ]; then
    state="started"
    target=$1
elif [ "$2" == "stop" ]; then
    state="stopped"
    target=$1
elif [ "$2" == "restart" ]; then
    state="restarted"
    target=$1
fi


ansible $target -m service -become -a "name=amplet2-client state=$state"
