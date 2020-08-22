# jkaptive
A fork of jkaptive 1.12 (a simple captive portal by Jan Kandziora): https://sourceforge.net/projects/jkaptive/

------

_Excerpts from original project wiki:_

### OVERVIEW
A captive portal is a software which intercepts the transfer of all HTTP traffic through a router and presents a login page to the user's web browser instead. Once the user has supplied a token (a special string), transfers aren't intercepted anymore until the lease the token offered expires.

jkaptive presents the login page and checks the token. The blocking of unticketed traffic is done through Linux' netfilter.

As no proxy server is involved, jkaptive has no performance penalty, nor does it create problems with non-HTTP traffic. Once the token is accepted, jkaptive is out of the way of any network packets completely.

For presenting the login page, jkaptive has a built-in webserver, so no additional webserver application is needed.

### Filtering
With the rules shown in section NETFILTER CONFIGURATION all unticketed HTTP traffic is redirected to jkaptive's login page, while all other unticketed traffic is rejected. jkaptive adds a netfilter rule which bypasses redirection and rejection for any single remote user host once a valid token has been given, and it automatically revokes that rule once the token expires.

Instead of rejection, all other kinds of netfilter rules can be applied, e.g. rate-limiting rules, giving full internet access to anyone, but full-speed only to paying customers. The example rules feature only rejection, though.

jkaptive can be configured to work on output traffic, too, so it's an easy way to add ticketing to a stand-alone internet terminal.

### User's view
From user's point of view, when he ... clicks on a bookmark in his browser, then it tries to load ... Instead of showing the desired page, the browser presents a login page. As soon the user has entered the token into the login field and that token is valid, the browser is redirected to the page of the original request and showing the [page]. In the background, full internet access has been allowed for the user's computer until the token expires. Then, the login page is given again.

### Tokens
Valid tokens are created using a simple algorithm by putting their expiry date together with some salt and checksum, permutate it and make a human-typeable form of it. No communication is needed between the program creating the token and jkaptive: all needed data is encoded into the token.

A simple implementation of a token generator is supplied with the jkaptive package, so it can be called by another application or have the algorithm copied into. The output is intended to be printed on a restaurant bill or similar.

The same token can't be used simultaneously by more than one user's computer as jkaptive keeps track of all currently used tokens and the ip address of the user's computer they belong to.

### Security
jkaptive tries to be secure in the way not compromising the host it runs on.  To change netfilter rules it has to run as the root user but to avoid exposing root access to a remote user, the built-in httpd used by jkaptive for serving the login page is run as a non-priviledged user (e.g. nobody). Both processes communicate via pipes and do only exchange tokens and status codes.

... the webserver starts a worker process for each file served and terminates it automatically after a while, so simple starvation/DOS attacks on it don't work. To work against bruteforce resource hoggers this isn't enough, though, so you have to create some site-specific netfilter rules and ressource limits throwing away such packets at netfilter level. Your Linux distribution might have documentation and templates for it.

... the webserver protects the token salt against bruteforcing - a pause of at least 500ms per request for the login page
means that a brute force attack would take hours to succeed. Each simultaneous connection to the login page from the same ip gets an extra penalty of 500ms. Note this applies only to the login HTML page. Any other pages or images, styles and scripts loaded from that or any other page are unaffected. ...

### LIMITATIONS

* ... circumvented by advanced users (aka "hackers") by sniffing for a ticketed IP address and then mimicing this address on their own computer ...
* Second, the token algorithm is not cryptographically secure. ...
* Another limitation is the storage of accepted tokens within the jkaptive process only. So if that process is terminated (e.g. by power-cycling the server), the list of accepted tokens is empty on next start: all users have to authenticate again. They may use their previous token once again, though, as long as it hasn't expired.

### PREREQUISITES
jkaptive is written in the Tcl scripting language so it obviously needs that interpreter to run. In addition it needs tclx and some sub-packages from the tcllib. ... the packages are:

* tcl     >= 8.5
* tclx    (8.4 is known to work)
* tcllib  (1.11.1 is known to work)

... ipsets may be used instead of a netfilter chain.  If your site has a great number of ticketed users at any time, the linear parsing of netfilter rules inside the jkaptive chain for ticketed ip addresses may take some more time that you want. With ipsets, the kernel uses a hash instead of a linear list, which should give you more performance. To use it, you need

* ipset binary
* ipset-aware kernel (CONFIG_IP_SET=y or m and CONFIG_IP_SET_HASH_IP=y or m).

This is completely optional, though. See CONFIGURATION below.

### CONFIGURATION
Very little configuration has to be supplied, as useful defaults apply. One single configuration item - a site specific salt - has to be supplied however. Jkaptive will refuse to start if it is not configured. The configuration file has ini style, one item per line. Please ensure the items are in the correct section. Lines starting with ; are comments.

```
[general]
;loglevel=4
;salt=mysalt

[httpd]
;user=nobody
;group=nogroup
;port=8088
;timeout=10
;webroot=/usr/share/jkaptive/webroot
;loginpage=login.html
;tokenfailpage=tokenfail.html
;tokenoccupiedpage=tokenoccupied.html
;tokenexpiredpage=tokenexpired.html
;error404page=error404.html
;error500page=error500.html

[netfilterd]
;backend=iptables
;iptables=/usr/sbin/iptables
;ipset=/usr/sbin/ipset
;chain=jkaptive
;mark=0x00200000
```

**loglevel** is 0=no log, 1=critical only, 2=critical and error, etc.  Loglevel 6 and above means all log messages are printed. The default is 4 (down to "notice") which won't clutter your syslog with unneeded messages.

The **salt** has to be supplied! **&#x1F53A;&#x1F53B;&#x1F53A; Please don't use `mysalt` but a site-specific string. &#x1F53A;&#x1F53B;&#x1F53A;** It doesn't need to have more than four characters as it gets shrunk to a 16-Bit value anyway. The salt has to be the same you use for the token generator.

**user** and **group** of the httpd have to be names of user and group of a least-priviledged account on your machine.

**port** is the port number the built-in webserver of jkaptive should run. It has to be an unused unpriviledged port.

**timeout** is a length in seconds which a httpd worker process may be present before it gets terminated by the main httpd process. This is a measure against starvation/DOS attacks to the webserver.

**webroot** has to point to a directory containing the login and error pages the build-in webserver of jkaptive should deliver to users.

**loginpage, tokenfailpage, tokenoccupiedpage, tokenoccupiedpage, tokenexpiredpage, tokenexpiredpage, error404page** and **error500page** are the names of the special HTML files within webroot.

**backend** is the backend to use for adding ip adresses of ticketed clients to the netfilter. It's either `iptables` or `ipset`.

**iptables** has to point to the iptables binary jkaptive should use to place its private rules into the netfilter. If the backend is set to `ipset`, this isn't used by jkaptive.

**ipset** has to point to the ipset binary jkaptive should use to place its private rules into the netfilter. If the backend is set to `iptables`, this isn't used by jkaptive.

**chain** is the private chain/set inside netfilter jkaptive should place its rules.

**mark** is a packet tracking mark like explained in iptables documentation. In general, this is a 32-bit integer (written in hex for easier understanding) with one single bit set. It is not important which bit is set, only that no other part of the netfilter uses the same bit; if it does, that will result to a big mess.

### NETFILTER CONFIGURATION
In addition to editing the configuration file `/etc/jkaptive.conf`, which is explained above, you have to supply some site-specific netfilter rules to make your captive portal actually work. There is a generic setup which works if no other firewall is interfering and a special one for use with SuSEfirewall2. For other distributions you can use the script for SuSEfirewall2 at `/usr/share/jkaptive/SuSEfirewall2` as a template for your own scripts.

... you can use the `ipset` netfilter framework in addition to `iptables`. The use of ipset is straightforward. Instead of a private chain "jkaptive" (or whatever you named it), jkaptive will use a private set "jkaptive" to store the ip addresses of ticketed users. The netfilter rules are a little different, please see below. The SuSEfirewall2 custom script can use ipset, too.

#### Generic setup

Without ipset, create an additional chain named **jkaptive**

`iptables -t mangle -N jkaptive`

With ipset, create a hash:ip set named **jkaptive** instead

`ipset create jkaptive hash:ip`

#### Activate jkaptive connection tracking:

Without ipset, use

`iptables -t mangle -A PREROUTING -j jkaptive`

With ipset, use

`iptables -t mangle -A PREROUTING -m set --match-set jkaptive src -j MARK --set-mark 0x00200000`

Redirect all unticketed HTTP traffic from inside (e.g. eth0) to outside to jkaptive server.

`iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -m mark ! --mark 0x00200000/0x00200000 -j REDIRECT --to-ports 8088`

The `jkaptive` chain name, mark bit and port number have to match the ones configured in `/etc/jkaptive.conf`.

It's recommended to rate-limit connections to the jkaptive server. Browsers try to access a lot of websites on startup simultaneously, and this will cause hundreds of simultaneous connections to the jkaptive server, making it fork and eat up hundreds of file descriptors in a short time. Ten connections per second should be enough to let at least one subwindow display the login page.

```
iptables -t filter -A INPUT -p tcp --dport 8088 -m state --state NEW -m recent --set
iptables -t filter -A INPUT -p tcp --dport 8088 -m state --state NEW -m recent --update --seconds 5 --hitcount 50 -j DROP
```

Only if you have an upstream gateway e.g at 192.168.1.1 which should provide DHCP/DNS (instead of the host jkaptive is running on), you need additional rules to let that traffic pass.

```
iptables -t filter -A FORWARD -d 192.168.1.1 -j ACCEPT
iptables -t filter -A FORWARD -s 192.168.1.1 -j ACCEPT
```

If your upstream gateway is delivering DHCP, but DNS is directly given by an internet server, specify

```
iptables -t filter -A FORWARD -p udp --dport 53 -j ACCEPT
iptables -t filter -A FORWARD -p udp --sport 53 -j ACCEPT
```

Now you can reject all other unticketed traffic from inside (e.g. eth0) to outside.

`iptables -t filter -A FORWARD -i eth0 -m mark ! --mark 0x00200000/0x00200000 --j REJECT --reject-with=icmp-admin-prohibited`

The mark has to be the same as above, of course.

If you want to filter traffic originating on the host running jkaptive, e.g. for an internet terminal, you need additional rules for the output chains:

without ipset: `iptables -t mangle -A OUTPUT -j jkaptive`

with ipset: `iptables -t mangle -A OUTPUT -m set --match-set jkaptive src -j MARK --set-mark 0x00200000`

both:
```
iptables -t nat -A OUTPUT -p tcp --dport 80 -m mark ! --mark 0x00200000/0x00200000 -j REDIRECT --to-ports 8088
iptables -t filter -A OUTPUT -d 127.0.0.1 -j ACCEPT
iptables -t filter -A OUTPUT -m mark ! --mark 0x00200000/0x00200000 --j REJECT --reject-with=icmp-admin-prohibited
```

Chain, mark and port have to match again, of course.

Now the host itself is filtered. This creates the problem it can't issue DNS requests to the upstream gateway.

If you have such an upstream gateway e.g. at 192.168.1.1, add `iptables -t filter -A OUTPUT -d 192.168.1.1 -j ACCEPT` before the REJECT line and it is fixed.

If your upstream gateway is delivering DHCP, but DNS is directly given by an internet server, add `iptables -t filter -A OUTPUT -p udp --dport 53 -j ACCEPT` before the REJECT line and it is fixed.

If your host is directly connected to a modem (using e.g. pppoe), both problems don't apply.

jkaptive will place its individual rules like `iptables -t mangle -A jkaptive -s $address -j MARK --set-mark 0x00200000` into the jkaptive chain when a token is accepted and automatically delete them once the token is expired.

Please note the kernel has to support the icmp-admin-prohibited reject method, otherwise you get a plain DROP instead.

#### SuSEfirewall2 setup
For SuSEfirewall2 instructions, see https://sourceforge.net/p/jkaptive/wiki/Home/

### INVOCATION
jkaptive is meant to be run as a daemon started by root. You can test it on root's command line with:

`/usr/sbin/jkaptive --loglevel 6`

Log messages are always sent to syslog, with the tag "jkaptive". Messages from the built-in webserver have the additional tag "httpd". If you want to start jkaptive automatically on system start, this should be done after the netfilter/firewall setup is done.

For openSUSE 12.1 and other distributions featuring systemd, a systemd script is provided. Test it with

```
systemctl --system daemon-reload
systemctl start jkaptive.service
systemctl status jkaptive.service
```

Installation as a system service can be done through `systemctl enable jkaptive.service`

jkaptive.service is linked to the multiuser.target (similar to runlevel 3).

### CREATING TOKENS
A simple utility for generating tokens is provided. Call it with something like

`/usr/bin/jkaptive-token mysalt "6 hours"` to create a six-hour token valid from now or

`/usr/bin/jkaptive-token mysalt 19:00` to create a token valid until 19:00 today or

`/usr/bin/jkaptive-token mysalt "2012-12-31 20:00"` to create a token valid until your new year's party starts.

First parameter has to be the same salt as set in `/etc/jkaptive.conf`. The second parameter has to be either a date/time specification or distance accepted by Tcl functions [clock format] and [clock add]. See clock(n) manpage for details.

### CUSTOMIZING THE WEB PAGES
The web pages provided by jkaptive at /usr/share/jkaptive/webroot can be seen as templates for your own creations. You can easily modify them or even add a whole bunch of new pages, images, scripts and styles.

#### Modifying templates
There are six files which are served directly by jkaptive's webserver:

**loginpage**
This page is delivered when any url is given to jkaptive

**tokenfailpage**
This page is delivered if the user supplied an invalid token, e.g. because of typing it wrong.

**tokenoccupiedpage**
This page is delivered if the user supplied a valid token which is used by another IP address, e.g. because he wanted to re-use a thrown-away token with another computer before it expired. Another reason this page shows up is because the DHCP lease expired (See CAVEATS) and the user got a new IP address and tried to re-register using the old token.

**tokenexpiredpage**
This page is delivered if the user supplied a token which has already expired, e.g. because of using some old token.

**error404page**
This page is delivered if the user supplies an URL to jkaptive that points somewhere it shouldn't. Usually that means some link on the other pages is wrong. The user should never be able to provoke this behaviour.

**error500page**
This page is delivered if something really bad happened with jkaptive. If it ever appears, prepare to file a bug report.

Please note all pages but the loginpage are only delivered after the user filled out the form on the loginpage - they never appear out of sudden when a token expires or any other error occurs.

All but the error pages should feature a HTML form which lets the user enter the token. This form should look like

```
<form action="%ROOT/login" method="get">
    <input type="text" name="token" size="12" maxlength="12" />
    <input type="submit" value="OK" />
    <input type="hidden" name="ourl" value="%OURL" />
</form>
```

**%ROOT** and **%OURL** are special strings which are replaced by a modified request root and the original URL the user provided before his request was redirected to jkaptive.

If you don't want to replace the templates, put your files into a directory and point the "webroot" configuration variable in `/etc/jkaptive.conf` to that directory. jkaptive's webroot directory must be readable by the user provided in its config file. Usually this means it has to be world-read/browseable. Same applies for all the files which are about to be served.

#### Adding files
If you want to have custom images, styles or scripts, or a printable PDF documentation how to obtain a token (or other fancy things) to be included into your very own captive portal, you can simply add these files into the webroot directory and use `<img src="%ROOT/warning.png">` in the HTML file to point the browser to the URL where it can load the image from. The same applies for all other links.

jkaptive finds out the MIME type of the file by looking at its filename extension. The following extensions are known to it: `css, gif, html, jpg, jpeg, js, pdf, png`

All files with unknown extension are served as text/plain. Please note it isn't possible to have a file named "login" in the webroot, as this is a special string to jkaptive triggering the login mechanism.

### CAVEATS

#### DNS/DHCP server
Before a web browser on the user's computer tries to load any HTML page through HTTP, it issues a DNS request for the host part of the address to find out which IP address to point the HTTP request to. jkaptive's default behaviour is to reject all forwarded traffic, even DNS and DHCP. This isn't a problem if you run a DNS/DHCP server/proxy somewhere inside the local network or the same host jkaptive runs on.

But if you have an upstream gateway providing this, e.g. a box given by your telco, it may also serve as the DNS/DHCP server in your network. In that case, you have to place additional netfilter rules (see NETFILTER CONFIGURATION) to allow forwarded traffic to that box.

To make it even more complicated, there are telco boxes out there which work as a router and DHCP server, but not as a local DNS repeater. In that case, the box will tell the user's computers a DNS server in the internet via DHCP. As it may change at the will of the telco, there is no other chance but to allow DNS traffic to and from all adresses. See NETFILTER CONFIGURATION again.

#### DHCP lease time
As all the filtering is done with ip addresses, is has to be made sure DHCP always gives the same IP address to the same computer as long the token has not expired. If you don't honor this, users may not use their full time of free internet access.  With ISC dhcpd, this is done through `/etc/dhcpd.conf`

```
default-lease-time
max-lease-time
min-lease-time
```

You have to specify a default lease time higher than the expiry time of the longest jkaptive token you have. Usually a setting of 86400 (one day) is ok. Specifing max and min lease times may be needed, too.

With the built-in dhcpd of dnsmasq, this is done on the command line through the -F/--dhcp-range option. See the manpage of dnsmasq and your distribution's documentation on how dnsmasq is embedded in it.

#### Packet marking
Make sure the packet tracking mark used by jkaptive (configured in `/etc/jkaptive.conf`) is used by jkaptive exclusively. The netfilter/firewall code already present on your machine may accidentally use the same bit, causing a lot of random glitches in conjunction with jkaptive.

So before activating jkaptive, list the mangle rules of your machine for lines having a **MARK** target: `iptables -t mangle -nvL | grep MARK` and make sure that the bit used by jkaptive is not used by any of them.

#### DHCP client (openSUSE specific)
There is a known glitch when the host jkaptive runs on get its own ip address via DHCP: as soon the lease expires, the network is reconfigured and SuSEfirewall2 is restarted, flushing all rules in the jkaptive chain. Users have to relogin with their old tokens after that. If you want to avoid this glitch, configure the host jkaptive runs on with a fixed IP address.
