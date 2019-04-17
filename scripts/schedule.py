#!/usr/bin/env python3
# Deploy schedules or list and identify any clashes
# Chris Gadd
# chris.gadd@vodafone.com
# 2017-05-01

import argparse
import subprocess
import sys
import os
import pathlib
import yaml
import itertools
from math import ceil
from collections import defaultdict


# Assuming this file is in /home/user/amp/scripts, variables are in /home/user/amp/ansible/vars/main.yml
directory = pathlib.Path(__file__).resolve().parent.parent
config = str(directory) + "/ansible/vars/main.yml"

schedDir = yaml.load(open(config))['schedDir']
playbook = str(directory) + "/ansible/pushSchedule.yml"


class fcolours:
	RED =		'\033[31m'
	GREEN =		'\033[32m'
	YELLOW =	'\033[33m'
	BLUE =		'\033[34m'
	MAGENTA =	'\033[35m'
	CYAN =		'\033[36m'
	RESET =		'\033[0m'

parser = argparse.ArgumentParser(description="Deploy or display test schedule for probes. \
											  With no arguments it will deploy an updated schedule to all probes.")
parser.add_argument("-d", help="Display schedule only", action='store_true')
parser.add_argument("-c", help="Show clashes only (two or more tests to or from a single probe)", action='store_true')
parser.add_argument("-s", help="Be strict about clashes - tests must be in the same direction", action='store_true')
parser.add_argument("-p", help="Show probe <probeid> only (can list multiple probes)", action='append')
parser.add_argument("-f", help="When only showing clashes or selected probes, also show other tests at same time",
					action='store_true')
parser.add_argument("-t", help="Specify one or more tests to display. Default is throughput only",
					choices=['throughput', 'icmp', 'dns', 'http'], type=str.lower, nargs='+')
parser.add_argument("-r", help="Resolution to display, in seconds", type=int, default=10)
args = parser.parse_args()
clashonly = args.c
resolution = args.r
probelist = args.p
full = args.f
display = args.d
strict = args.s
testtypes = args.t

showtput = True
showicmp = False
showdns = False
showhttp = False
if testtypes:
	if 'throughput' in testtypes:
		showtput = True
	else:
		showtput = False
	if 'icmp' in testtypes:
		showicmp = True
	if 'dns' in testtypes:
		showdns = True
	if 'http' in testtypes:
		showhttp = True

if not display:
	subprocess.call(["ansible-playbook", playbook])
	sys.exit()

print("Reading schedules...")
timetable = defaultdict(list)
for filename in os.listdir(schedDir):
	if filename.endswith(".schedule"):
		filepath = os.path.join(schedDir, filename)
		# check file is legit, since the playbook may have downloaded an empty file (if the probe no longer exists)
		if not os.path.getsize(filepath):
			print("File {} is empty, ignoring".format(filepath))
			continue
		# use probeid without the FQDN if it exists
		probeid = filename.split('.')[0]
		with open(filepath, 'r') as stream:
			# Work through all the tests for this probe
			for test in yaml.load(stream)['tests']:
				# find start time to nearest resolution
				bucket = int(ceil(test['start'] / resolution)) * resolution
				# join list of targets (some of which may be lists themselves) and remove FQDN if it exists
				target = ' & '.join(itertools.chain.from_iterable(itertools.repeat(item, 1) if isinstance(item, str)
									else item for item in test['target'])).split('.')[0]
				if test['test'] == 'throughput':
					# don't bother checking duration for now, it's 10s upload then download
					timetable[bucket].append([probeid, ">T>", target])
					# extend to all buckets
					for step in range(resolution, 10, resolution):
						timetable[bucket + step].append([probeid, ">T>", target])
					# now the reverse direction
					timetable[bucket + 10].append([probeid, "<T<", target])
					# extend to all buckets
					for step in range(resolution, 10, resolution):
						timetable[bucket + 10 + step].append([probeid, "<T<", target])
				elif test['test'] == 'icmp':
					timetable[bucket].append([probeid, ">I>", target])
				elif test['test'] == 'dns':
					timetable[bucket].append([probeid, ">D>", target])
				elif test['test'] == 'http':
					# HTTP tests use the arguments to provide the URL, with a leading '-u'
					target = test['args'].split()[1]
					timetable[bucket].append([probeid, ">H>", target])

# output as a timetable
for bucket, activity in sorted(timetable.items()):
	showBucket = False
	thisBucketTxt = fcolours.YELLOW + "{:3}s:".format(bucket) + fcolours.RESET
	thisBucketTxtExtra = ""

	# find clashes
	sources = [test[0] for test in activity]
	targets = [test[2] for test in activity]
	# a clash is considered the same probe originating more than 1 test,
	clashesS = set([item for item in sources if sources.count(item) > 1])
	# terminating more than 1 test,
	clashesT = set([item for item in targets if targets.count(item) > 1])
	# or originating and terminating at the same time
	clashesI = set(sources).intersection(targets)
	if strict:
		clashes = clashesS | clashesT
	else:
		clashes = clashesS | clashesT | clashesI

	# now review each test in this time bucket
	for test in activity:
		source, testtype, target = test
		# target may not be a single probe for some test (eg ICMP)

		if source == target:
			# AMP never tests to itself
			continue

		thisTestTxt = " " + source + fcolours.MAGENTA + testtype + fcolours.RESET + target + " "
		if (   ('T' in testtype and showtput)
			or ('I' in testtype and showicmp)
			or ('D' in testtype and showdns)
			or ('H' in testtype and showhttp)):

			if  (  # show this test if:
				(not probelist or (source in probelist or target in probelist))	  # probe of interest
				and (not clashonly or (source in clashes or target in clashes))   # clash to view
				):
				showBucket = True
				thisBucketTxt = thisBucketTxt + thisTestTxt
			else:
				# may not be interested in this probe, 'full' flag will determine that
				thisBucketTxtExtra = thisBucketTxtExtra + thisTestTxt
			
	if full:
		thisBucketTxt = thisBucketTxt + fcolours.GREEN + ":::" + fcolours.RESET + thisBucketTxtExtra

	if showBucket:
		print(thisBucketTxt)
