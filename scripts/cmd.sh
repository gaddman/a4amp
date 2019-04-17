#!/usr/bin/env bash
# Shortcut to adhoc Ansible command, with some tweaks to target specific probes
# Christopher Gadd
# June 2017
# chris.gadd@vodafone.com

show_help() {
        echo "Run command on selected probes"
        echo -e "\tUsage: `basename $0` limit command"
        echo -e "\tLimit can be one of: 'endpoints', 'probes', 'ipv6', an access type,"
        echo -e "\t  a location, a hardware type, or a wildcard match on the probe name"
        echo -e "\teg `basename $0` UFB 'mtr -rwbc5 www.kiwibank.co.nz'"
        }

if [ "$1" == "-h" ] || [ -z "$1" ] || [ -z "$2" ]; then
        show_help
        exit
fi

# get matching probelist
if [ "$1" == 'probes' ]; then
	probelist="probes"
elif [ "$1" == 'endpoints' ]; then
	probelist="endpoints"
elif [[ "$1" == *'*' ]]; then
	probelist="$1"
elif [ "$1" == 'ipv6' ]; then
	echo "Connecting to probes to find active IPv6 units..."
	# get IPV6 data from all probes, find those with valid addresses, print comma separated, strip the last comma
	allprobes=$(ansible probes -m setup -a 'gather_subset=!all,!min,network filter=ansible_default_ipv6')
	probelist=$(echo "$allprobes" | grep -B3 '"address"' | awk -v ORS=',' '/SUCCESS/ {print $1}' | sed 's/.$//')
else
	# text match
	probelist=$( grep -v '^\[' /etc/ansible/hosts | awk -v pattern="$1" '$0 ~ pattern {print $1}' | tr '\n' ',' | sed 's/.$//')
fi

if [ -z "$probelist" ]; then
	echo "No matching probes found"
	exit
fi

echo "Running command against probes $probelist"
ansible $probelist -m shell -a "$2"
