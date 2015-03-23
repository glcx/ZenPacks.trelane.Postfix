#!/bin/bash
# this script is designed to deliberately use basic BASH with extensive comments for easy modification
# while this script does call 'ssh' twice, it's still quite fast.
#
# this script takes one command line argument, the hostname, and returns nagios formatted output (OK|var1=val1...)
#
# returned values are:
#   queue length
#   sent (to a remote host)
#   delivered (to a local account)
#   spam (rejected as spam)
#
# note that the strings to parse for may vary by system, so they are broken out for easy editing below
# 
# to use this script the zenoss user will need to be able to run 'postqueue' and read postfix's
# if you need to invoke 'sudo' simply do so in the command below
# note that these are specific to RHEL/CentOS (and probably Fedora) but can be easily modified by editing these:
POSTQUEUE_PATH=/usr/sbin/postqueue
POSTFIXLOG_PATH=/var/log/maillog

# (not implemented yet) edit these to provide regexp (grep) criteria for each type of message 
#SENT_REGEXP=""
#RECEIVED_REGEXP=""
#SPAM_REGEXP=""

#gets the number of mail messages in the queue
QUEUE=$(ssh "$1" $POSTQUEUE_PATH -p | grep Requests | awk '{print $5}')

#gets stats for the last 5 minutes 
DATE=$(date --date="-5 minutes" '+%b %d %R')
ssh "$1" grep -A 999999 \""$DATE"\" $POSTFIXLOG_PATH > ~/postfix.log

SENT=$(grep postfix /home/zenoss/postfix.log | grep status=sent | grep -v -E 'relay=mail(pre|post)filter' | \
grep -v 'relay=127.0.0.1' | grep -v discarded | grep -Ec '(OK|Ok)')
RECEIVED=$(grep postfix /home/zenoss/postfix.log | grep -E 'relay=mailpostfilter' | grep -v discarded | grep -vc orig_to)
SPAM=$(grep discarded /home/zenoss/postfix.log | grep -c SPAM)

rm /home/zenoss/postfix.log

echo "OK|queue=$QUEUE sent=$SENT received=$RECEIVED spam=$SPAM"


 
