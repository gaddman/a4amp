#!/usr/bin/env bash

# Chris Gadd
# 11-12-2017

#  tc uses the following units when passed as a parameter.
#  kbps: Kilobytes per second
#  mbps: Megabytes per second
#  kbit: Kilobits per second
#  mbit: Megabits per second
#  bps: Bytes per second
#       Amounts of data can be specified in:
#       kb or k: Kilobytes
#       mb or m: Megabytes
#       mbit: Megabits
#       kbit: Kilobits
#  To get the byte figure from bits, divide the number by 8 bit
#  From https://www.iplocation.net/traffic-control
#
TC=/sbin/tc
IF=$(ip route | head -n1 | awk '{print $5}')	# Interface
RATE=900mbit	#slightly less than max speed

start() {

    $TC qdisc add dev $IF handle 1: root htb default 10
    $TC class add dev $IF parent 1: classid 1:1 htb rate $RATE
    $TC class add dev $IF parent 1:1 classid 1:10 htb rate $RATE

}

stop() {

    $TC qdisc del dev $IF root

}

restart() {

    stop
    sleep 1
    start

}

show() {

    $TC -s qdisc ls dev $IF

}

case "$1" in

  start)

    echo -n "Starting bandwidth shaping: "
    start
    echo "done"
    ;;

  stop)

    echo -n "Stopping bandwidth shaping: "
    stop
    echo "done"
    ;;

  restart)

    echo -n "Restarting bandwidth shaping: "
    restart
    echo "done"
    ;;

  show)

    echo "Bandwidth shaping status for $IF:\n"
    show
    echo ""
    ;;

  *)

    pwd=$(pwd)
    echo "Usage: $(/usr/bin/dirname $pwd)/tc.bash {start|stop|restart|show}"
    ;;

esac

exit 0

