#!/usr/bin/env bash
##set -ex
prog=$(basename "$0")

# print usage
usage(){
cat <<END
################################################
##### $prog (June 2015)
##### (c) June 2015 - Peter Forret - Brightfish
Usage:
  $prog [options] [host1,host2,host3] [command]
  runs [command] on all specified hosts via ssh  
  [host]      can be ip address, hostname or user@hostname
  [command]   command to run remotely or '-' to read from stdin
  
Options:
  -h        : show this usage
  -v        : verbose (more debugging output)
  -b        : don't wait for remote process to finish (run in bg)
              (so runs +- simultaneously on all servers)
  -i        : do SSH initialisation (one-time only) 
              (copy SSH pub key to remote host if necessary)
  -u [user] : use this username for shh login (default: $USER)
    
Examples:
  $prog fileserver1,fileserver2,fileserver3 "df -h"
    show disk usage of 3 fileservers
  
  $prog -b -u sql db1,db2,db3 "/etc/restart_sql.sh"
    run a remote script as user 'sql'
  
  cat cleanup_sh | $prog admin@server1,root@server2 -
    run a local script on 2 remote servers

END
	exit
}

# exit if there are no arguments
[ $# -eq 0 ] && usage

# prefix output 
prefix_feed(){
	gawkok=$(which gawk)
	if [ -n "$gawkok" ] ; then 
		# gawk is installed - we can use strftime
		gawk "{ print strftime(\"[$*][%Y-%m-%d %T]\"), \$0; fflush(); }"
	else
		# no gawk installed - use awk
		awk "{print \"[$*]\", \$0;}"
	fi
}

trace(){
	if [ $debug -gt 0 ] ; then
		echo $* | prefix_feed "### trace"
	fi
}
# initialize default values
background=0
debug=0
init=0

# parse options
set -- $(getopt -n"$prog" -u "hvbiu:" "$@")
defuser=$USER

while [ $# -gt 0 ] ; do
	case "$1" in
		-b) background=1
			trace "-b: run commnd in background";;
		-i) init=1
			trace "-i: first initialize ssh authentication";;	
		-v) debug=1
			trace "-v: entering verbose mode";;	
		-u) defuser="$2"
			trace "-u: using [$2] as default user"
			shift;;
		-h) usage;;
		--) shift;break;;
		*) break;;
	esac
	shift
done

hostlist="$1"
shift
command="$*"
tmpcmd=""

cleanup_before_exit () {
	# this code is run before exit
	if [ -f "$tmpcmd" ] ; then
		rm -f "$tmpcmd"
	fi
	trace "$prog finished"
}

# trap catches the exit signal and runs the specified function
trap cleanup_before_exit EXIT

# if necessary, read the sequence of commands first
if [ "$command" == "-" ] ; then
	# first read from stdin , then send it to all hosts
	echo "### Read commands from stdin (end with CTRL-D)" | prefix_feed "$prog"
	tmpcmd="/tmp/$prog.$$.temp"
	cat > "$tmpcmd"
	trace "commands saved in [$tmpcmd]"
fi
	
hosts=$(echo "$hostlist" | tr "," "\n")
for host in $hosts ; do
	# first check for user@host notation
	user=$defuser
	if [ "$host" != "$(echo "$host" | tr '@' ':')" ] ; then
		## first parse username, if any
		user=$(echo "$host" | cut -d@ -f1)
		host=$(echo "$host" | cut -d@ -f2)
	fi
	trace "connect as $user @ $host "

	# now find IP address
	ip=$(ping -c 1 "$host" | sed 's/[\(\)]*//g' | awk 'NR == 1 {print $3}')
	if [ "$host" == "$ip" ] ; then
		echo "### $prog: execute as [$user] on [$host]" | prefix_feed "$host"
	else 
		echo "### $prog: execute as [$user] on [$host] - [$ip]" | prefix_feed "$host"
	fi
	
	# check if initialisation should happen
	if [ $init -gt 0 ] ; then
		echo "### $prog: first initialize ssh access to $user@$host" | prefix_feed "$host"
		ssh-copy-id "$user@$host" 2>&1 | grep -v "attempting to log in" | grep -v '^$' | prefix_feed "$host"
	else
		if [ "$command" == "" ] ; then
			echo "### $prog: no command given" | prefix_feed "$host"
		else
			if [ $background == 1 ]; then
				# start in bg
				trace "starting background process on $host (no waiting)"
				if [ -n "$tmpcmd" ] ; then
					(< "$tmpcmd" ssh "$user@$host" sh | prefix_feed "$host") &
				else
					(ssh "$user@$host" "$command" | prefix_feed "$host") &
				fi
			else
				# start in fg
				trace "starting foreground process on  $host"
				if [ -n "$tmpcmd" ] ; then
					trace "reading commands from $tmpcmd "
					< "$tmpcmd" ssh "$user@$host" sh | prefix_feed "$host"
				else
					trace "now executing [$command] "
					ssh "$user@$host" "$command" | prefix_feed "$host"
				fi
			fi
		fi
	fi

done
sleep 1
if [ $background == 1 ]; then
	# will make sure 1st returned stdout will not come behind the prompt
	(echo " ") & 
fi
