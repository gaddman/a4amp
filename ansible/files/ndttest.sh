#!/usr/bin/env bash
# Created by Darren Fong - Network performance 12/11/2018
# This script is used to test to all Samknows servers to find the latency, download speed and upload speed for both IPv4 and IPv6

# Nodes for speed tests
SPEED="
ndt-iupui-mlab1-akl01.measurement-lab.org
ndt-iupui-mlab1-wlg02.measurement-lab.org
ndt-iupui-mlab1-lhr05.measurement-lab.org
ndt-iupui-mlab1-lhr03.measurement-lab.org
ndt-iupui-mlab1-nuq02.measurement-lab.org
ndt-iupui-mlab1-nuq03.measurement-lab.org
ndt-iupui-mlab1-nuq04.measurement-lab.org
ndt-iupui-mlab1-nuq06.measurement-lab.org
ndt-iupui-mlab1-nuq07.measurement-lab.org
ndt-iupui-mlab1-syd01.measurement-lab.org
ndt-iupui-mlab1-syd02.measurement-lab.org
"
# Nodes for latency tests
LATENCY="
ndt-iupui-mlab1-akl01.measurement-lab.org
ndt-iupui-mlab1-wlg02.measurement-lab.org
ndt-iupui-mlab1-syd01.measurement-lab.org
ndt-iupui-mlab1-syd02.measurement-lab.org
ndt-iupui-mlab1-nuq02.measurement-lab.org
ndt-iupui-mlab1-nuq03.measurement-lab.org
ndt-iupui-mlab1-nuq04.measurement-lab.org
ndt-iupui-mlab1-nuq06.measurement-lab.org
ndt-iupui-mlab1-nuq07.measurement-lab.org
ndt-iupui-mlab1-lhr03.measurement-lab.org
ndt-iupui-mlab1-lhr05.measurement-lab.org
ndt-iupui-mlab1-hnd01.measurement-lab.org
ndt-iupui-mlab1-hnd02.measurement-lab.org
ndt-iupui-mlab1-jnb01.measurement-lab.org
ndt-iupui-mlab1-bom01.measurement-lab.org
ndt-iupui-mlab1-bom02.measurement-lab.org
ndt-iupui-mlab1-fln01.measurement-lab.org
"
#Help function
function HELP {
    echo -e "\\nBasic usage: ndttest.sh [optional flags]"\\n
    echo "If any options are present then only those tests specified will be run."
    echo "-p  Ping test"
    echo "-s  Speed test"
    echo "-t  Traceroute. This won't be run unless specified directly."
    echo "-h  Displays this help message. No further functions are performed."
    exit 1
}

while getopts "hpst" opt; do
    case $opt in
    p)
        oPing=1
        options=1
        ;;
    s)
        oSpeed=1
        options=1
        ;;
    t)
        oTrace=1
        options=1
        ;;
    h)  #show help
        HELP
        ;;
    \?) #unrecognized option - show help
        echo -e \\n"Option -$OPTARG not allowed."
        HELP
        ;;
    esac
done
shift $(( OPTIND-1 ))


echo "Testing to all NDT servers"

# Run NDT speed tests to selected locations
if [ -z "$options" ] || [ "$oSpeed" ]; then
    echo -e "\nRunning speed tests\n================================================================================================================================================================\n"

    for location in $SPEED; do
        v4result=$(web100clt -n $location -4 --disablemid --disablesfw)
        v6result=$(web100clt -n $location -6 --disablemid --disablesfw)
        ipaddress=$(host $location)
        ipv4=$(echo "$ipaddress" | awk '/has address/ {print $4}')
        ipv6=$(echo "$ipaddress" | awk '/IPv6/ {print $5}')
        v4lat=$(ping $location -4 -c5 | awk '/rtt/ {print $4}')
        v4latency=${v4lat%%/*}
        v6lat=$(ping $location -6 -c5 | awk '/rtt/ {print $4}')
        v6latency=${v6lat%%/*}
        v4download=$(echo "$v4result" | awk '/server to client/ {print $14 $15}')
        v4upload=$(echo "$v4result" | awk '/client to server/ {print $13 $14}')
        v6download=$(echo "$v6result" | awk '/server to client/ {print $14 $15}')
        v6upload=$(echo "$v6result" | awk '/client to server/ {print $13 $14}')
        echo -e "$location\n\n$ipv4 has:\nLatency: $v4latency\nDownload speed: $v4download\nUpload speed: $v4upload"
        echo -e "\n\n$ipv6 has:\nLatency: $v6latency ms\nDownload speed: $v6download\nUpload speed: $v6upload\n\n----------------------------------------------------------------------------------------------------------------------------------------------------------------\n"

    done
fi

# Run ping tests to selected locations
if [ -z "$options" ] || [ "$oPing" ]; then
    echo -e "\nRunning ping tests\n================================================================================================================================================================\n"

    for location in $LATENCY; do
        ipaddress=$(host $location)
        ipv4=$(echo "$ipaddress" | awk '/has address/ {print $4}')
        ipv6=$(echo "$ipaddress" | awk '/IPv6/ {print $5}')

        v4=$(ping $location -q -n -4 -c5 | awk '/rtt/ {printf "%0.0f", $4}')
        v4l=${v4%%/*}
        v6=$(ping $location -q -n -6 -c5 | awk '/rtt/ {printf "%0.0f", $4}')
        v6l=${v6%%/*} 
        echo -e "$location\n\nIPv4 address: $ipv4\nIPv6 address: $ipv6\n\nLatency: \nIPv4: $v4l\nIPv6: $v6l\n\n----------------------------------------------------------------------------------------------------------------------------------------------------------------\n"

    done
fi

# Run traceroute tests to selected locations
if [ "$oTrace" ]; then
    echo -e "\nRunning traceroutes\n================================================================================================================================================================\n"

    for location in $LATENCY; do
        ipaddress=$(host $location)
        ipv4=$(echo "$ipaddress" | awk '/has address/ {print $4}')
        ipv6=$(echo "$ipaddress" | awk '/IPv6/ {print $5}')

        v4=$(mtr -4rwbc5 $location)
        v6=$(mtr -6rwbc5 $location)
        echo -e "$location\n\nIPv4 address: $ipv4\nIPv6 address: $ipv6\n\nTrace: \n\nIPv4:\n$v4\n\nIPv6:\n$v6\n\n----------------------------------------------------------------------------------------------------------------------------------------------------------------\n"

    done
fi
