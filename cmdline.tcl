

## Parse the command line.
if {[catch {::cmdline::getoptions argv {
		{-loglevel.arg {} "loglevel"}
		{-version "output version and exit"}
		} \
		{[options] -- options are:}} parm]} {
  ## Print usage message.
  ${log}::error $parm
  exit 127
}


## Version output?
if {[dict get $parm -version]} {
	puts stderr "jkaptive 1.12"
	puts stderr "Copyright (C) 2012 Jan Kandziora"
	puts stderr "License GPLv2: GNU GPL version 2 <http://gnu.org/licenses/gpl.html>."
	puts stderr "This is free software: you are free to change and redistribute it."
	puts stderr "There is NO WARRANTY, to the extent permitted by law."
	puts stderr "\nWritten by Jan Kandziora <jjj@gmx.de>"
	exit 127
}


## Set filename for inifile.
set inifile /etc/jkaptive.conf


## Set loglevel while reading ini file.
loglevel $::log [expr {[dict get $parm -loglevel] ne {}?[dict get $parm -loglevel]:$default_loglevel}]


## From now, handle all uncaught errors globally.
if {[catch {


## Switch by argument count.
switch -- [llength $argv] {
	0 {
	}
	default {
		## Arguments given. Error.
  	${::log}::error "USAGE: $::argv0 [options]"
		exit 127
	}
}
