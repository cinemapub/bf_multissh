# bf_multissh
Execute bash command on multiple servers at once

## Example

run "uname -a" on 3 hosts, one by one

	multissh.sh host1,host2,host3 "uname -a"

run "uname -a" on 3 hosts, all at the same time

	multissh.sh -b host1,host2,host3 "uname -a"

run "uname -a" on 3 hosts, using username 'admin'

    multissh.sh -u admin host1,host2,host3 "uname -a"

