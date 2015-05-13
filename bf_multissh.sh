#!/usr/bin/env bash
set -e

usage(){
cat <<'EOT'
$0 [options] [host1,host2,host3] [command]
	runs [command] on all specified hosts via ssh
[options]: 
	-b : run in background (so +- simultaneously on all servers)
	-u [user]	: use this user as default ssh login
EOT
exit 0;
}

# exit if there are no arguments
[ $# -eq 0 ] && usage

# initialize default values
background=0
user=$(whoami)

# parse options
set -- `getopt -n$0 -u -a --longoptions "help" "hbu:" "$@"`

while [ $# -gt 0 ] ; do
	case "$1" in
		-b) background=1;;
		-u) user=$2; shift;;
		-h| --help) usage;;
		--) shift;break;;
		*) break;;
	esac
	shift
done

hostlist="$1"
shift
command="$*"

cleanup_before_exit () {
# this code is run before exit
echo -e " "
}
# trap catches the exit signal and runs the specified function
trap cleanup_before_exit EXIT

# OK now do stuff
hosts=$(echo $hostlist | tr "," "\n")
for host in $hosts ; do
	ip=$(ping -c 1 $host | awk 'NR == 1 {gsub("[\(\)]*",""); print $3}')
	if [ "$host" == "$ip" ] ; then
		echo -- execute as [$user] on [$host]
	else 
		echo -- execute as [$user] on [$host] - [$ip]
	fi
	if [ $background == 1 ]; then
		(ssh $user@$host "$command" | sed "s/^/[$host]:/") &
	else
		ssh $user@$host "$command"
	fi
done
if [ $background == 1 ]; then
	# will make sure 1st returned stdout will not come behind the prompt
	(echo " ") & 
fi
