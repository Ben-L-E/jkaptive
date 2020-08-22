

## Open ini file.
set ini [::ini::open $inifile r]


## Set loglevel.
if {[dict get $parm -loglevel] eq {}} {
	loglevel $::log [::ini::value $ini general loglevel $default_loglevel]
}


## Get salt.
set salt [::ini::value $ini general salt { }]
if {$salt eq { }} {
	error "you have to provide a site-specific salt in /etc/jkaptive.conf"
}


## Get config items for httpd.
set user [::ini::value $ini httpd user nobody]
set group [::ini::value $ini httpd user nogroup]
set http_port [::ini::value $ini httpd port 8088]
set http_starving_timeout [expr 1000*[::ini::value $ini httpd timeout 10]]
set webroot [::ini::value $ini httpd webroot /usr/share/jkaptive/webroot]
set loginpage [::ini::value $ini httpd loginpage login.html]
set tokenfailpage [::ini::value $ini httpd tokenfailpage tokenfail.html]
set tokenexpiredpage [::ini::value $ini httpd tokenexpiredpage tokenexpired.html]
set tokenoccupiedpage [::ini::value $ini httpd tokenoccupiedpage tokenoccupied.html]
set error404page [::ini::value $ini httpd error404page error404.html]
set error500page [::ini::value $ini httpd error500page error500.html]


## Get config items for netfilterd.
set backend [::ini::value $ini netfilterd backend iptables]
set iptables [::ini::value $ini netfilterd iptables /usr/sbin/iptables]
set ipset [::ini::value $ini netfilterd iptables /usr/sbin/ipset]
set chain [::ini::value $ini netfilterd chain jkaptive]
set mark [::ini::value $ini netfilterd mark 0x00200000]
