#!/usr/bin/env bash

# Find the host streaming a particular YouTube video
# From https://stackoverflow.com/a/13264639/3592326

[ -z "$1" ] && printf "usage: `basename $0` <video ID>\n" && exit 1

response=$(curl -s "http://www.youtube.com/get_video_info?video_id=$1")
host=$(echo "$response" | sed  's/.*\%252F\([^\%]*googlevideo.com\).*/\1/p' | head -1)
title=$(echo $response | sed 's/.*title=\([^\&]*\).*/\1/p' | head -1 | sed 's/+/ /g')
IP=$(dig +short $host | tail -1)

echo "Video ID: $1 ($title)"
echo "Host: $host ($IP)"
