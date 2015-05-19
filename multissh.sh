#!/usr/bin/env bash
set -e
prog=$(basename $0)

# print usage
usage(){
	echo "===================================================" >&2
	echo "$prog [options] [host1,host2,host3] [command]" >&2
	echo "  runs [command] on all specified hosts via ssh" >&2
	echo "  [host] can be ip address, hostname or user@hostname" >&2
	echo "  [options]:" >&2 
	echo "    -b        : start in background (so +- simultaneously on all servers)" >&2
	echo "    -u [user] : use this username for shh login (default: $USER)" >&2
	exit
}

# exit if there are no arguments
[ $# -eq 0 ] && usage

# prefix output 
prefix_feed(){
	word=$1
	gawkok=$(which gawk)
	if [ -n "$gawkok" ] ; then 
		# gawk is installed - we can use strftime
		gawk "{ print strftime(\"[$*][%Y-%m-%d %T]\"), \$0; fflush(); }"
	else
		# no gawk installed - use awk
		awk "{print \"[$*]\", \$0;}"
	fi
}
# initialize default values
background=0
user=$(whoami)

# parse options
set -- `getopt -n$prog -u -a --longoptions "help" "hbu:" "$@"`
defuser=$USER
while [ $# -gt 0 ] ; do
	case "$1" in
		-b) background=1;;
		-u) defuser=$2; shift;;
		-h| --help) usage;;
		--) shift;break;;
		*) break;;
	esac
	shift
done

hostlist="$1"
shift
command="$*"
echo -e "### STARTED" | prefix_feed $prog
tmpcmd=""
cleanup_before_exit () {
	# this code is run before exit
	if [ -f "$tmpcmd" ] ; then
		rm -f "$tmpcmd"
	fi
	echo -e "### FINISHED" | prefix_feed $prog
}

# trap catches the exit signal and runs the specified function
trap cleanup_before_exit EXIT

# if necessary, read the sequence of commands first
if [ "$command" == "-" ] ; then
	# first read from stdin , then send it to all hosts
	echo "### $prog: read commands from stdin" | prefix_feed stdin
	tmpcmd="/tmp/$prog.$$.temp"
	cat > $tmpcmd
fi
	
hosts=$(echo $hostlist | tr "," "\n")
for host in $hosts ; do
	
	# first check for user@host notation
	user=$defuser
	if [ "$host" != "$(echo $host | tr '@' ':')" ] ; then
		## first parse username, if any
		user=$(echo $host | cut -d@ -f1)
		host=$(echo $host | cut -d@ -f2)
	fi
	
	# now find IP address
	ip=$(ping -c 1 $host | sed 's/[\(\)]*//g' | awk 'NR == 1 {print $3}')
	if [ "$host" == "$ip" ] ; then
		echo "### $prog: execute as [$user] on [$host]" | prefix_feed $host
	else 
		echo "### $prog: execute as [$user] on [$host] - [$ip]" | prefix_feed $host
	fi
	

	if [ $background == 1 ]; then
		# start in bg
		if [ -n "$tmpcmd" ] ; then
			(cat "$tmpcmd" | ssh $user@$host sh | prefix_feed $host) &
		else
			(ssh $user@$host "$command" | prefix_feed $host) &
		fi
	else
		# start in fg
		if [ -n "$tmpcmd" ] ; then
			cat "$tmpcmd" | ssh $user@$host sh | prefix_feed $host
		else
			ssh $user@$host "$command" | prefix_feed $host
		fi
	fi
done
sleep 1
if [ $background == 1 ]; then
	# will make sure 1st returned stdout will not come behind the prompt
	(echo " ") & 
fi
