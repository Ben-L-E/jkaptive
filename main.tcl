

## Wait for a process to exit in background.
proc waitfor {pid interval command} {
	set exitcode [wait -nohang $pid]
	if {$exitcode eq {}} {
		after $interval [list waitfor $pid $interval $command]
	} {
		uplevel #0 $command $exitcode
	}
}	


## Log and notice exited childs.
proc childexited {args} {
	${::log}::warn "httpd terminated unexpectedly: $args"
	set ::cpid {}
}


## Clean exit.
proc cleanexit {args} {
	## Remove all iptables address entries.
	netfilter_remove_all

	## Really exit.
	${::log}::notice "exiting"
	tcl_exit {*}$args
}


## Setup pipes so the servers can communicate.
pipe fromfather tochild
pipe fromchild tofather
fconfigure $tofather -buffering line
fconfigure $fromfather -buffering line
fconfigure $tochild -buffering line
fconfigure $fromchild -buffering line


## Flush data so it won't duplicate on father and child.
flush stdout
flush stderr


## Main loop.
set exit_renamed 0
while {1} {
	## Fork http server from netfilter server.
	set cpid [fork]
	if {$cpid == 0} {
		## Child process.
		${::log}::notice "starting httpd on port $http_port"

		## Switch to other user.
		if {[catch {
			id group $group
			id user $user
		}]} {
			error "httpd: changing to user $user, group $group denied"
		}

		## Start http server.
		socket -server http_accept $::http_port

		## Wait endless.
		vwait endless

		## Fallthrough exit.
		error "httpd: fallthrough exit"
	} {
		## Father process.

		## Add an exit funtion and traps for some signals.
		if {!$exit_renamed} {
			rename exit tcl_exit
			rename cleanexit exit
			signal trap {HUP INT QUIT TERM} exit
			incr exit_renamed
		}	

		## Wait for child to exit in background.
		waitfor $cpid 1000 childexited

		## Check every minute for expired tickets.
		netfilter_remove_expired 60000

		## Call netfilter command on any command over the pipe from the http server.
		fileevent $fromchild readable [list netfilter_command $fromchild $tochild]

		## Run event loop until child exited.
		vwait cpid
	}
}
