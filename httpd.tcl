

## Setup magic number.
set http_magic [md5::md5 -hex [clock seconds]]


## Remember worker pids and ips served.
set http_workers {}
set http_ips {}


## Read a file.
proc http_readfile {path} {
	set fd [open $path r]
	set data [read $fd]
	close $fd
	return $data
}


## Respond with a text.
proc http_respond {sock code type ourl body} { 
	## Get textual respond message from code.
	switch $code {
		200 { set message "OK" }
		404 { set message "File Not Found" }
		500 { set message "Internal Server Error" }
		default { set message "???" }
	}

	## Replace magic strings.
	regsub -all -- %ROOT $body /$::http_magic body
	regsub -all -- %OURL $body $ourl body

	## Actually write the content.
	set body [encoding convertto [encoding system] $body]
	puts $sock "HTTP/1.0 $code $message\nContent-Type: $type; charset=[encoding system]\nConnection: close\nContent-length: [string length $body]\n"
	fconfigure $sock -translation binary
	puts -nonewline $sock $body
}


## Read a file without translating it.
proc http_readfile_binary {path} {
	set fd [open $path r]
	fconfigure $fd -translation binary
	set data [read $fd]
	close $fd
	return $data
}


## Respond with binary data.
proc http_respond_binary {sock code type body} { 
	## Get textual respond message from code.
	switch $code {
		200 { set message "OK" }
		404 { set message "File Not Found" }
		500 { set message "Internal Server Error" }
	}

	## Actually write the content.
	puts $sock "HTTP/1.0 $code $message\nContent-Type: $type;\nConnection: close\nContent-length: [string length $body]\n"
	fconfigure $sock -translation binary
	puts -nonewline $sock $body
}


## Receive command from the worker process.
proc http_receive_worker_command {pid fromself toself fromchild tochild} {
	## Get data from worker.
	if {[gets $fromchild command]<0 || [eof $fromchild]} {
		## Error or EOF from worker. That means it terminated.
		${::log}::debug "httpd: error or EOF from worker httpd $pid"

		## Cleanup pipes.
		catch {close $fromself}
		catch {close $toself}
		catch {close $fromchild}
		catch {close $tochild}
	} {
		## Escalate received command to netfilter server.
		${::log}::debug "httpd: command $command escalated from worker httpd $pid to netfilterd"
		puts $::tofather $command

		## Get result from netfilter server and send to worker.
		set result [gets $::fromfather]
		${::log}::debug "httpd: result $result from netfilterd sent to worker httpd $pid"
		puts $tochild $result
	}

	## Return to event loop.
}


## Accept a socket connection.
proc http_accept {sock ip port} {
	## Setup pipes so the the httpd server can communicate with the worker process.
	pipe fromfather tochild
	pipe fromchild tofather
	fconfigure $tofather -buffering line
	fconfigure $fromfather -buffering line
	fconfigure $tochild -buffering line -blocking 0
	fconfigure $fromchild -buffering line -blocking 0

	## Fork a worker process from http server.
	set cpid [fork]

	## Remember client ip for worker.
	## Countermeasure against brute-forcing the token salt.
	dict set ::http_ips $ip $cpid {}
	${::log}::debug "httpd: ips $::http_ips"

	## Distiguish worker from main httpd now.
	if {$cpid == 0} {
		## Child process.
		${::log}::debug "httpd: starting worker httpd [pid] for $ip"

		## Start worker.
		http_worker $fromfather $tofather $sock $ip

		## Exit worker.
		exit
	} {
		## Remember worker and terminate starving worker after a while.
		dict set ::http_workers $cpid ip $ip
		dict set ::http_workers $cpid timer [after $::http_starving_timeout [list http_worker_starving $cpid $sock]]
		${::log}::debug "httpd: workers $::http_workers"

		## Wait for worker to exit in background.
		waitfor $cpid 1000 [list http_worker_exit $fromfather $tofather $fromchild $tochild $sock]

		## Setup an event handler for receiving commands from the worker process.
		fileevent $fromchild readable [list http_receive_worker_command $cpid $fromfather $tofather $fromchild $tochild]
	}

	## Return to event loop.
}


## Call netfilter through main httpd server.
proc http_netfilter_call {ifd ofd args} {
	## Send command to netfilter_command.
	puts $ofd $args

	## Wait for result.
	set result [gets $ifd]

	## Throw error on remote error.
	switch -- $result {
		OK { return -code ok $result }
		default { return -code error $result }
	}
}


## Serve a connection.
proc http_worker {ifd ofd sock ip} {
	## Catch unknown errors.
	if {[catch {
		## Get request header.
		gets $sock line
		set host {}
		for {set c 0} {[gets $sock temp]>=0 && $temp ne "\r" && $temp ne ""} {incr c} {
			## Catch the "Host: " line.
			regexp {^Host: (.*)$} $temp match host
			
			## Ignore malformed requests.
			if {$c == 30} {
				${::log}::notice "httpd\[[pid]\]: too many lines by $ip"
				close $sock
				return
			}
		}

		## Skip request if closed by client.
		if {[eof $sock]} {
			${::log}::notice "httpd\[[pid]\]: connection closed by $ip"
			close $sock
			return
		}

		## Get method, url and protocol version.
		foreach {method url version} $line break

		## Add protocol and host part to url.
		set url http://$host$url

		## Respond by method.
		switch -exact $method {
			GET {
				## Get data from uri.
				set uri [uri::split $url]
				ncgi::input [dict get $uri query]
				set token [string range [ncgi::value token] 0 11]
				set ourl [ncgi::value ourl]
				set magic [lindex [split [dict get $uri path] /] 0]
				set iurl [lrange [split [dict get $uri path] /] 1 end]
				${::log}::debug "httpd\[[pid]\]: ip $ip uri $uri token $token iurl $iurl ourl $ourl magic $magic"

				## Check for magic.
				if {$magic eq $::http_magic} {
					## Magic number is correct. Check internal url.
					switch -- $iurl {
						login {
							## Login page.
							## Check how many connections the ip already has and insert a
							## short pause to work against brute-forcing the salt.
							set btime [expr 250*[llength [dict get $::http_ips $ip]]]
							${::log}::debug "httpd\[[pid]\]: waiting ${btime}ms until responding $ip"
							after $btime
							
							## Check token.
							set expires [token_check $::salt $token]
							${::log}::debug "httpd\[[pid]\]: salt $::salt check [token_check $::salt $token] expires $expires"
							if {$expires ne {}} {
								## Token valid, but maybe expired.
								if {$expires<=[clock seconds]} {
									## Token already expired.
									${::log}::notice "httpd\[[pid]\]: token $token has expired [clock format $expires -format "%Y-%m-%d %H:%M"], could not serve $ip"

									## Show token expired page.
									http_respond $sock 200 text/html $ourl [http_readfile [file join $::webroot $::tokenexpiredpage]]
								} {
									## Add permission for caller.
									if {[catch {http_netfilter_call $ifd $ofd $token $ip $expires} err]} {
										## Something bad happened.
										${::log}::info "httpd\[[pid]\]: escalated $err for $ip"

										## Check for errors.
										switch -- [lindex $err 0] {
											TOKEN_OCCUPIED {
												## Token already occupied.
												${::log}::notice "httpd\[[pid]\]: token occupied, could not serve $ip"

												## Show token occupied page.
												http_respond $sock 200 text/html $ourl [http_readfile [file join $::webroot $::tokenoccupiedpage]]
											}
											default {
												## Internal server error.
												${::log}::notice "httpd\[[pid]\]: internal server error from $ip"
												
												## Show error page.
												http_respond $sock 500 text/html $ourl [http_readfile [file join $::webroot $::error500page]]
											}
										}
									} {
										## Token accepted.
										${::log}::notice "httpd\[[pid]\]: token $token (expires [clock format $expires -format "%Y-%m-%d %H:%M"]) accepted for $ip"

										## Redirect to original url.
										puts $sock "HTTP/1.0 302 Found\nLocation: $ourl\nConnection: close\nContent-length: 0\n"
									}
								}	
							} {
								## Token wrong.
								${::log}::notice "httpd\[[pid]\]: wrong token from $ip"

								## Show token fail page.
								http_respond $sock 200 text/html $ourl [http_readfile [file join $::webroot $::tokenfailpage]]
							}
						}
						default {
							## Load file on any other internal url.
							## Remove .. from internal url and make it relativ to webroot.
							set path [file normalize $::webroot/[file normalize /$iurl]]

							## Determine the content type by extension.
							${::log}::debug "httpd\[[pid]\]: path $path extension [file extension $path]"
							switch -- [file extension $path] {
								.html { set type text/html }
								.css { set type text/css }
								.js { set type text/javascript }
								.pdf { set type application/pdf }
								.jpg - .jpeg { set type image/jpeg }
								.png { set type image/png }
								.gif { set type image/gif }
								default { set type text/plain }
							}

							## Determine textual or binary response.
							if {[lindex [split $type /] 0] eq "text"} {
								## Textual response. Read file.
								if {[catch {http_readfile $path} body]} {
									## Fail. Respond with error page.
									http_respond $sock 404 text/html $ourl [http_readfile [file join $::webroot $::error404page]]
								} {
									## Success. Respond with actual data
									http_respond $sock 200 $type $ourl $body
								}	
							} {
								## Binary response. Read file.
								if {[catch {http_readfile_binary $path} body]} {
									## Fail. Respond with error page.
									http_respond $sock 404 text/html $ourl [http_readfile [file join $::webroot $::error404page]]
								} {
									## Respond binary file content.
									http_respond_binary $sock 200 $type $body
								}
							}
						}
					}	
				} {
					## Path is something unknown.
					${::log}::info "httpd\[[pid]\]: connection attempt from $ip"

					## Respond with login page.
					http_respond $sock 200 text/html $url [http_readfile [file join $::webroot $::loginpage]]
				}
			}
			default {
				## No such method.
				${::log}::notice "httpd\[[pid]\]: unsupported method '$method' by $ip"
			}
		}
	} msg]} {
		## Unknown error.
		${::log}::notice "httpd\[[pid]\]: $msg"
	}

	## End communcation with web browser.
	catch {close $sock}

	## End communication with main httpd.
	close $ifd
	close $ofd
}


## Notify worker exit.
proc http_worker_exit {fromself toself fromchild tochild sock pid type code} {
	${::log}::debug "httpd: worker httpd $pid ended with $type code $code."
	
	## Cleanup pipes, should they be still open.
	catch {close $fromself}
	catch {close $toself}
	catch {close $fromchild}
	catch {close $tochild}

	## Close socket.
	catch {close $sock}

	## Cancel starving timer.
	after cancel [dict get $::http_workers $pid timer]

	## Forget this worker.
	set ip [dict get $::http_workers $pid ip]
	dict unset ::http_ips $ip $pid
	if {[dict get $::http_ips $ip] eq {}} {
		dict unset ::http_ips $ip
	}
	dict unset ::http_workers $pid

	${::log}::debug "httpd: ips $::http_ips"
	${::log}::debug "httpd: workers $::http_workers"
}


## Terminate starving workers.
proc http_worker_starving {pid sock} {
	## Kill worker if still existing.
	if {[dict exists $::http_workers $pid]} {
		${::log}::warn "httpd: terminating starving worker $pid."

		## Kill it.
		catch {kill $pid}

		## Close socket.
		catch {close $sock}
	}
}	

