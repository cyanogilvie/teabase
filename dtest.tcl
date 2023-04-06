#!/usr/local/bin/tclsh

file mkdir /tmp/build
cd /tmp/build
foreach file [glob -nocomplain /src/local/*] {
	set fqfn	[file join /src/local $file]
	if {[file exists $fqfn]} {
		exec cp -r $fqfn .
	}
}
exec -ignorestderr autoconf >@ stdout
exec -ignorestderr ./configure --enable-symbols --with-tcl=/usr/local/lib >@ stdout
file delete -- {*}[glob -nocomplain tools/bin/*]
exec -ignorestderr make clean test TESTFLAGS=[lindex $argv 0] >@ stdout
