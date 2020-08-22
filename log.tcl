

## Setup logger.
set log [logger::init global]

proc syslog {loglevel message} {
	exec -- logger -p daemon.$loglevel -t jkaptive -- $message
}
proc syslog_debug {message} {syslog debug $message}
proc syslog_info {message} {syslog info $message}
proc syslog_notice {message} {syslog notice $message}
proc syslog_warn {message} {syslog warn $message}
proc syslog_error {message} {syslog error $message}
proc syslog_critical {message} {syslog crit $message}

${::log}::logproc debug syslog_debug
${::log}::logproc info syslog_info
${::log}::logproc notice syslog_notice
${::log}::logproc warn syslog_warn
${::log}::logproc error syslog_error
${::log}::logproc critical syslog_critical


## Set loglevel.
proc loglevel {logger level} {
	set levels {critical error warn notice info debug}
	foreach name $levels {
		${logger}::disable $name 
	}
	foreach name [lrange $levels 0 [expr $level-1]] {
		${logger}::enable $name 
	}
}	


## Set default loglevel.
set default_loglevel 4
loglevel $::log $default_loglevel


## Log errors with the logging facility, exit.
proc bgerror {args} \
{
	${::log}::error "fatal: [lindex $args 0]"
	exit 127
}

proc error {args} \
{
	${::log}::error "fatal: [lindex $args 0]"
	exit 127
}
