lassign $argv build_root tclsh package_name package_version

puts -nonewline {Termdebug -ex set\ print\ pretty\ on --args }
puts -nonewline [string map {{ } {\ }} $tclsh]
puts -nonewline { tests/all.tcl -load }
puts -nonewline [string map {{ } {\ }} {apply {{dir n v} {source [file join $dir pkgIndex.tcl]; package require -exact $n $v}} }]
puts -nonewline [string map {{ } {\ }} [list $build_root $package_name $package_version]]
puts -nonewline { }
if {[info exists env(TESTFLAGS)]} {
	puts -nonewline $env(TESTFLAGS)
}
puts ""
