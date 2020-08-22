

## Tokens and addresses.
set ::netfilter_tokens {}
set ::netfilter_addresses {}


## Netfilter server.
proc netfilter_command {ifd ofd} {
	## Get address to annotate and expire time.
	foreach {token address expires} [gets $ifd] break
	${::log}::debug "token supplied: $token $address $expires"

	## Fail if no valid ip address.
	if {![ regexp {^([[:digit:]]{1,3})\.([[:digit:]]{1,3})\.([[:digit:]]{1,3})\.([[:digit:]]{1,3})$} $address match v1 v2 v3 v4 ]} {
		${::log}::warn "could not add permission for invalid address $address"
		puts $ofd "IPADDRESS_INVALID $address"
		return
	}

	## Check single values.
	foreach v [ list $v1 $v2 $v3 $v4 ] \
	{
		## Remove leading zeroes to avoid octal math.
		regsub {^0*([[:digit:]].*)$} $v {\1} v

		## Fail if the value is not an integer at all.
		## Fail if value is not within the boundaries.
		if {![string is integer -strict $v ]||($v<0)||($v>255)} {
			${::log}::warn "could not add permission for invalid address $address"
			puts $ofd "IPADDRESS_INVALID $address"
			return
		}
	}

	## We have a canonical address.
	set address $v1.$v2.$v3.$v4

	## Fail if token already in use by another address.
	if {[dict exists $::netfilter_tokens $token]} {
		if {[dict get $::netfilter_tokens $token] ne $address} {
			## Yes. Fail.
			${::log}::warn "token $token already occupied by [dict get $::netfilter_tokens $token]"
			puts $ofd "TOKEN_OCCUPIED $token"
			return
		}
	}

	## Fail if expires isn't an integer.
	if {![string is integer -strict $expires ]} {
		${::log}::warn "could not add permission for address $address: invalid expire time $expires"
		puts $ofd "EXPIRES_INVALID $expires"
		return
	}

	## Keep track of tokens and addresses.
	dict set ::netfilter_tokens $token $address
	dict set ::netfilter_addresses $expires $token $address
	${::log}::debug "tokens: $::netfilter_tokens"
	${::log}::debug "addresses: $::netfilter_addresses"

	## Call iptables/ipset.
	switch -- $::backend {
		iptables {
			if {[catch {exec $::iptables -t mangle -A $::chain -s $address -j MARK --set-mark $::mark} err]} {
				${::log}::warn "could not add permission for address $address, iptables failed: $err"
				puts $ofd "NETFILTER_FAILED $err"
			} {
				${::log}::info "added permission for $address"
				puts $ofd "OK"
			}
		}
		ipset {
			if {[catch {exec $::ipset add $::chain $address} err]} {
				${::log}::warn "could not add permission for address $address, ipset failed: $err"
				puts $ofd "NETFILTER_FAILED $err"
			} {
				${::log}::info "added permission for $address"
				puts $ofd "OK"
			}
		}
	}
}


## Remove all the mentioned addresses from netfilter.
proc netfilter_remove {addresses} {
	foreach {token address} $addresses {
		## Call iptables/ipset.
		switch -- $::backend {
			iptables {
				if {[ catch {exec $::iptables -t mangle -D $::chain -s $address -j MARK --set-mark $::mark} err]} {
					${::log}::warn "could not remove permission for $address, iptables failed: $err"
				} {
					${::log}::info "removed permission for $address"
				}
			}
			ipset {
				if {[ catch {exec $::ipset del $::chain $address} err]} {
					${::log}::warn "could not remove permission for $address, ipset failed: $err"
				} {
					${::log}::info "removed permission for $address"
				}
			}
		}
	}
}


## Remove all addresses from netfilter.
proc netfilter_remove_all {} {
	foreach addresses [dict values $::netfilter_addresses] {
		netfilter_remove $addresses
	}
	set ::netfilter_tokens {}
	set ::netfilter_addresses {}
}


## Remove all expired addresses.
proc netfilter_remove_expired {interval} {
	## Log.
	${::log}::debug "checking for expired tickets"

	## Go through all entries by ascending expire time.
	set now [clock seconds]
	foreach expires [lsort -integer [dict keys $::netfilter_addresses]] {
		## Break if expire time is in the future.
		if {$expires>$now} break

		## Remove all addresses for this expire time.
		netfilter_remove [dict get $::netfilter_addresses $expires]

		## Remove these tokens and addresses from our table.
		foreach {token address} [dict get $::netfilter_addresses $expires] {
			dict unset ::netfilter_tokens $token
		}	
		dict unset ::netfilter_addresses $expires
	}

	${::log}::debug "tokens: $::netfilter_tokens"
	${::log}::debug "addresses: $::netfilter_addresses"

	## Call again in a while.
	after $interval [list netfilter_remove_expired $interval]
}
