#!/usr/local/bin/tclsh

file mkdir /tmp/build
cd /tmp/build
foreach file {
	aclocal.m4
	configure.ac
	tclconfig
	generic
	library
	tests
	bench
	pkgIndex.tcl.in
	Makefile.in
	teabase
} {
	exec cp -a [file join /src/local $file] .
}
exec -ignorestderr autoconf >@ stdout
exec -ignorestderr ./configure {*}[lindex $argv 1] --with-tcl=/usr/local/lib >@ stdout
exec -ignorestderr make clean benchmark TESTFLAGS=[lindex $argv 0] >@ stdout
