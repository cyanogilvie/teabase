#!/usr/local/bin/tclsh

file mkdir /tmp/build
cd /tmp/build
foreach file [glob -nocomplain /src/local/*] {
	set fqfn	[file join /src/local $file]
	if {[file exists $fqfn]} {
		exec cp -a $fqfn .
	}
}
exec -ignorestderr autoconf >@ stdout
puts "configure args: ([lindex $argv 1])"
# Without --enable-symbols, tcl.m4 hard codes the flags in tclConfig.sh's CFLAGS_OPTIMIZE /after/ any value we can configure
exec -ignorestderr ./configure --enable-symbols {*}[lindex $argv 1] --with-tcl=/usr/local/lib >@ stdout
switch -- [lindex $argv 2] {
	pgo {
		exec -ignorestderr make clean pgo >@ stdout
		exec -ignorestderr make benchmark BENCHFLAGS=[lindex $argv 0] >@ stdout
	}
	default {
		exec -ignorestderr make clean benchmark BENCHFLAGS=[lindex $argv 0] >@ stdout
	}
}
