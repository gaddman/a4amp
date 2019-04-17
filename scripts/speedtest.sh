#!/usr/bin/env bash
# Run various speedtests from a probe
# Chris Gadd
# 2016-10-25

show_help() {
	echo "Run speedtest from probe"
	echo -e "\tUsage: $0 [options] [probeid]"
	echo -e "\t   -v: verbose output"
	}

yaml() {
	python -c "import yaml;print(yaml.load(open('$1'))$2 or '')"
}

# Get config filename
# This file should be in <ampDir>/scripts, config in <ampDir>/ansible/vars
FILE=$(readlink -f "$0")
DIRECTORY=$(dirname $FILE)
CONFIG=$(dirname $DIRECTORY)/ansible/vars/main.yml


# Parse command line parameters
verbose=0
while getopts "h?v" opt; do
	case "$opt" in
	h|\?)
		show_help
		exit 0
		;;
	v)  verbose=1
		;;
	esac
done
if [ -z "$1" ]; then
	show_help
	exit
fi
probe=${@:$OPTIND:1}


echo "*** There are many ways to measure speed, understand the differences before drawing conclusions! ***"
echo "Enter speedtest type: 1 = Amplet, 2 = speedtest.net, 3 = iperf, 4 = ndt, 5 = wget, or all (enter = all)"
read testtype
echo "Enter destination server to test against: akl, wlg, or chc (enter = akl)"
read dest

# Set defaults if nothing provided
if [ -z "$testtype" ]; then
	testtype="all"
fi
if [ -z "$dest" ]; then
	dest="akl"
fi

# Additional parameters
wgetfile="50MB.bin"
testduration=10
case $dest in
	akl)
		destination=$(yaml $CONFIG "['location2endpoint'][0]['Auckland']")
		ndtdestination="ndt-iupui-mlab1-akl01.measurement-lab.org"
		;;
	wlg)
		destination=$(yaml $CONFIG "['location2endpoint'][0]['Wellington']")
		ndtdestination="ndt-iupui-mlab1-wlg02.measurement-lab.org"
		;;
	chc)
		destination=$(yaml $CONFIG "['location2endpoint'][0]['Christchurch']")
		ndtdestination="ndt-iupui-mlab1-wlg02.measurement-lab.org"
		;;
	*)
		destination=$(yaml $CONFIG "['location2endpoint'][0]['Auckland']")
		ndtdestination="ndt-iupui-mlab1-akl01.measurement-lab.org"
esac

# AMP test
if [ "$testtype" = "1" ] || [ "$testtype" = "all" ]; then
	echo -e "\nTesting speed using amp-throughput..."
	collector=$(yaml $CONFIG "['server']['collector']")
	result=$(ssh $probe "sudo amp-throughput -t $testduration -d 2 --cacert /etc/amplet2/keys/$collector.pem --cert /etc/amplet2/keys/$probe/$collector.cert --key /etc/amplet2/keys/$probe/key.pem -- $destination")
	if [ "$verbose" = "1" ]; then
		echo "$result"
	else
		down=$(echo "$result" | awk '$2=="server" {print $11}')
		up=$(echo "$result" | awk '$2=="client" {print $11}')
		echo "Down: $down Mbps / Up: $up Mbps"
	fi
fi

# Speedtest.net (restrict to preferred servers)
if [ "$testtype" = "2" ] || [ "$testtype" = "all" ]; then
	echo -e "\nTesting speed using speedtest-cli..."
	servers=$(yaml $CONFIG "['ooklaServers']")
	result=$(ssh $probe "speedtest $servers --socket")
	if [ "$verbose" = "1" ]; then
		echo "$result"
	else
		down=$(echo "$result" | awk '$1=="Download:" {print $2}')
		up=$(echo "$result" | awk '$1=="Upload:" {print $2}')
		echo "Down: $down Mbps / Up: $up Mbps"
	fi
fi

# iperf
if [ "$testtype" = "3" ] || [ "$testtype" = "all" ]; then
	echo -e "\nTesting speed using iperf (TCP)..."
	# Download
	ssh $destination "iperf3 --one-off --server --daemon"
	resultdown=$(ssh $probe "iperf3 --time $testduration --reverse --client $destination")
	down=$(echo "$resultdown" | awk '/receiver/ {print $7}')
	# Upload
	ssh $destination "iperf3 --one-off --server --daemon"
	resultup=$(ssh $probe "iperf3 --time $testduration --client $destination")
	up=$(echo "$resultup" | awk '/sender/ {print $7}')
	if [ "$verbose" = "1" ]; then
		echo "$resultdown"
		echo "$resultup"
	else
		echo "Down: $down Mbps / Up: $up Mbps"
	fi
fi

# ndt
if [ "$testtype" = "4" ] || [ "$testtype" = "all" ]; then
	echo -e "\nTesting speed using ndt..."
	result=$(ssh $probe "web100clt -n $ndtdestination")
	up=$(echo "$result" | awk '/outbound/ {print $13}')
	down=$(echo "$result" | awk '/inbound/ {print $14}')
	if [ "$verbose" = "1" ]; then
		echo "$result"
	else
		echo "Down: $down Mbps / Up: $up Mbps"
	fi
fi


# wget
if [ "$testtype" = "5" ] || [ "$testtype" = "all" ]; then
	echo -e "\nTesting speed using wget..."
	ssh $destination "sudo service apache2 start"
	result=$(ssh $probe "wget --report-speed=bits --progress=bar:force -O /dev/null http://$destination/$wgetfile 2>&1")
	ssh $destination "sudo service apache2 stop"
	if [ "$verbose" = "1" ]; then
		echo "$result"
	else
		down=$(echo "$result" | awk '/saved/ {print substr($3,2)}')
		echo "Down: $down Mbps"
	fi
fi
