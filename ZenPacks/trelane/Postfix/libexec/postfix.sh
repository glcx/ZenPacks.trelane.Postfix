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
# to use this script the zenoss user will need to be able to run 'postqueue' and read postfix's
# if you need to invoke 'sudo' simply do so in the command below



try() {
        "$@"
        if [ $? -ne 0 ]; then
                echo "Command failure: $@"
                exit 1
        fi
}

die() {
        echo $*
        exit 1
}



#OS Detection
#We try to detect the OS, but just in case, the paths are broken out below for easy editing
#please send me more log file location/OS pairs and I'll add them -mgmt
#
# 20151103 : echo $? did not work well under certains conditions.
# 20151103 : -oStrictHostKeyChecking to automatically add the host key. It will raise an error the first time the script runs.
# -oStrictHostKeyChecking to automatically add the host key. It will raise an alert the first time the script runs.
if [ $(try ssh -oStrictHostKeyChecking=no "$2"@"$1" 'test -f /etc/redhat-release ; echo $?') -eq 0 ]; then
	#we're on redhat
	POSTFIX_SYSLOG_PATH=/var/log/maillog
else
	#we're on ubuntu/debian
	POSTFIX_SYSLOG_PATH=/var/log/mail.log
fi


# note that these are specific to RHEL/CentOS (and probably Fedora) but can be easily modified by editing these:
POSTQUEUE_PATH=/usr/sbin/postqueue
POSTFIX_SNIPPET=/tmp/"1".postfix.log

# (not implemented yet) edit these to provide regexp (grep) criteria for each type of message 
#SENT_REGEXP=""
#RECEIVED_REGEXP=""
#SPAM_REGEXP=""

#gets the number of mail messages in the queue by reading the last line.
QUEUE=$(try ssh "$2"@"$1" $POSTQUEUE_PATH -p | tail -1)
if [ "$QUEUE" = "Mail queue is empty" ]
then
	QUEUE=0
else
	QUEUE=$(echo "$QUEUE" | awk '{print $5}')
fi 

#error handling
if [ "$QUEUE" = "" ]; then
  QUEUE=0
fi
   

#20151103 : syslog date is in english. just force the lang to be sure of the date format
DATE=$(LC_TIME=en_IE.UTF-8 date --date="-5 minutes" '+%b %e %R')

#20151103 : awk is able to manage dates efficiently
try ssh $2@$1 "awk -v date=\"$DATE\" '\$0 >= date' $POSTFIX_SYSLOG_PATH" > "$POSTFIX_SNIPPET"

SENT=$(grep postfix "$POSTFIX_SNIPPET" | grep status=sent | grep -v -E 'relay=mail(pre|post)filter' | \
grep -v 'relay=127.0.0.1' | grep -v discarded | grep -Ec '(OK|Ok)')
RECEIVED=$(grep postfix "$POSTFIX_SNIPPET" | grep -E 'relay=mailpostfilter' | grep -v discarded | grep -vc orig_to)
SPAM=$(grep discarded "$POSTFIX_SNIPPET" | grep -c SPAM)

rm "$POSTFIX_SNIPPET"

echo "OK|queue=$QUEUE sent=$SENT received=$RECEIVED spam=$SPAM"
# If we are here, everything went fine. Let's exit.
exit 0
