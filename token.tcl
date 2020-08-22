

## Check for valid token.
proc token_check {salt token} {
	## Decode token.
	if {[catch {::base64::decode ${token}} token]} {
		## Fail. 
		return
	}

	## Get xor permuation value and data string.
	if {[binary scan $token cua8 xor data]!=2} {
		## Fail. 
		return
	}

	## Undo the xor permutation of the token.
	set sdata {}
	binary scan $data c[string length $data] data
	foreach byte $data {
		append sdata [binary format c [expr {$byte^$xor}]]
	}

	## Get data from unpermutated token.
	if {[binary scan $sdata iususu expires tsalt crc16]!=3} {
		## Fail. 
		return
	}

	## Check salt.
	if {$tsalt ne [::crc::crc16 $salt]} {
		## Fail. 
		return
	}

	## Check crc.
	if {$crc16 ne [::crc::crc16 [string range $sdata 0 5]]} {
		## Fail. 
		return
	}

	## Ok. Return expiry date.
	return $expires
}
