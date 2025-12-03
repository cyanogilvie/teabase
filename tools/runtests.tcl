lassign $argv \
	source_root \
	pkg_dir \
	tclsh \
	package_name \
	package_version

set loadarg [list apply {{dir n v} {source [file join $dir pkgIndex.tcl]; package require -exact $n $v}} $pkg_dir $package_name $package_version]
exec $tclsh [file join $source_root tests/all.tcl] \
	-load $loadarg \
	{*}[if {[info exists env(TESTFLAGS)]} {set env(TESTFLAGS)}] \
	>@ stdout 2>@ stderr
