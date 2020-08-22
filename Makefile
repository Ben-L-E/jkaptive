.PHONY: all clean install

PREFIX?=/usr

all: jkaptive

clean:
	-rm jkaptive

install: all
	mkdir -p $(BUILDROOT)$(PREFIX)/sbin
	cp jkaptive $(BUILDROOT)$(PREFIX)/sbin/
	mkdir -p $(BUILDROOT)$(PREFIX)/bin
	cp jkaptive-token $(BUILDROOT)$(PREFIX)/bin/
	mkdir -p $(BUILDROOT)/etc/systemd/system
	cp jkaptive.conf $(BUILDROOT)/etc
	cp jkaptive.service $(BUILDROOT)/etc/systemd/system/
	mkdir -p $(BUILDROOT)$(PREFIX)/share/jkaptive
	cp -a webroot $(BUILDROOT)$(PREFIX)/share/jkaptive/
	cp SuSEfirewall2 $(BUILDROOT)$(PREFIX)/share/jkaptive/
	mkdir -p $(BUILDROOT)$(PREFIX)/share/doc/packages/jkaptive
	cp README COPYING $(BUILDROOT)$(PREFIX)/share/doc/packages/jkaptive/

jkaptive: top.tcl log.tcl cmdline.tcl inifile.tcl httpd.tcl token.tcl netfilterd.tcl main.tcl bottom.tcl
	cat $^ >$@
	chmod 755 $@
