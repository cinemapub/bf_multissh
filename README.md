# bf_multissh
Execute bash command on multiple servers at once

## Example

run "uname -a" on 3 hosts, one by one

	multissh.sh host1,host2,host3 "uname -a"

run "uname -a" on 3 hosts, all at the same time

	multissh.sh -b host1,host2,host3 "uname -a"

run "uname -a" on 3 hosts, using username 'admin'

    multissh.sh -u admin host1,host2,host3 "uname -a"

run a number of commands on several hosts

	cat commands.sh | multissh.sh admin@host1,root@host2 -
	
## Usage

	multissh.sh [options] [host1,host2,host3] [command]
	  runs [command] on all specified hosts via ssh
	  [host] can be ip address, hostname or user@hostname
	  [options]:
		-b        : start in background (so +- simultaneously on all servers)
		-u [user] : use this username for shh login (default: peter)

