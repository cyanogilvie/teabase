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
	pkgIndex.tcl.in
	Makefile.in
	teabase
} {
	exec cp -a [file join /src/resolvelocal $file] .
}
exec -ignorestderr autoconf >@ stdout
exec -ignorestderr ./configure --enable-symbols --with-tcl=/usr/local/lib >@ stdout
exec -ignorestderr make clean test TESTFLAGS=[lindex $argv 0] >@ stdout
