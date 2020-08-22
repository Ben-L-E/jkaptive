#!/usr/bin/tclsh
## /------>
## |
## | jkaptive - a simple captive portal
## |
## | Author: Jan Kandziora <jjj@gmx.de>
## | Version: 1.9
## |
## \-----------------<
##
##
## LICENSE
## =======
## I, Jan Kandziora, the author of jkaptive, grant you the right
## to use, copy, distribute and modify this software under the terms of the
## GNU General Public License(GPL), Version 2 (see file COPYING).
##


## Load required packages.
package require Tclx
package require inifile
package require cmdline
package require logger
package require uri
package require html
package require md5
package require ncgi
package require base64
package require crc16
