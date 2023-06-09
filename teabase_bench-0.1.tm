package require math::statistics

namespace eval ::teabase_bench {
	namespace export *

	variable match		*
	variable run		{}
	variable skipped	{}
	variable skip		{}

	# Override this to a new lambda to capture the output
	variable output {
		{lvl msg} {puts $msg}
	}

	namespace path [concat [namespace path] {
		::tcl::mathop
	}]

proc output {lvl msg} { #<<<
	variable output
	tailcall apply $output $lvl $msg
}

#>>>
proc _intersect3 {list1 list2} { #<<<
	set firstonly       {}
	set intersection    {}
	set secondonly      {}

	set list1	[lsort -unique $list1]
	set list2	[lsort -unique $list2]

	foreach item $list1 {
		if {[lsearch -sorted $list2 $item] == -1} {
			lappend firstonly $item
		} else {
			lappend intersection $item
		}
	}

	foreach item $list2 {
		if {[lsearch -sorted $intersection $item] == -1} {
			lappend secondonly $item
		}
	}

	list $firstonly $intersection $secondonly
}

#>>>
proc _readfile fn { #<<<
	set h	[open $fn r]
	try {
		read $h
	} finally {
		close $h
	}
}

#>>>
proc _writefile {fn dat} { #<<<
	set h	[open $fn w]
	try {
		puts -nonewline $h $dat
	} finally {
		close $h
	}
}

#>>>
proc _run_if_set script { #<<<
	if {$script eq ""} return
	uplevel 2 $script
}

#>>>
proc _pick {mode variant patterns} { #<<<
	set chain	0
	set found	0
	set res [lmap {pat e} $patterns {
		if {!$chain && ![string match $pat $variant]} continue
		if {$e eq "-"} {
			set chain	1
			continue
		}
		set chain	0
		switch -exact -- $mode {
			first - first!	{return $e}
			all - all!		{set found 1; set e}
			default	{error "Invalid _pick mode: ($mode)"}
		}
	}]
	if {!$found && [string match *! $mode]} {
		error "No pattern matches for \"$variant\""
	}
	set res
}

#>>>
proc _verify_res {variant retcodes expected match_mode got options} { #<<<
	variable current_bench

	if {[dict get $options -code] ni $retcodes} {
		teabase_bench::output error "Error: $got\n[dict get $options -errorinfo]"
		throw [list BENCH BAD_CODE $current_bench $variant $retcodes [dict get $options -code]] \
			"$current_bench/$variant: Expected codes [list $retcodes], got [dict get $options -code]"
	}

	switch -- $match_mode {
		exact  { if {$got eq $expected} return }
		glob   { if {[string match $expected $got]} return }
		regexp { if {[regexp $expected $got]} return }
		default {
			throw [list BENCH BAD_MATCH_MODE $match_mode] \
				"Invalid match mode \"$match_mode\", should be one of exact, glob, regexp"
		}
	}

	throw [list BENCH BAD_RESULT $current_bench $variant $match_mode $expected $got] \
		"$current_bench/$variant: Expected ($match_mode): -----------\n$expected\nGot: ----------\n$got"
}

#>>>
proc _make_stats times { #<<<
	set res	{}

	foreach stat {
		arithmetic_mean min max number_of_data
		sample_stddev sample_var
		population_stddev population_var
	} val [math::statistics::basic-stats $times] {
		dict set res $stat $val
	}
	dict set res median [math::statistics::median $times]
	dict set res harmonic_mean [/ [llength $times] [+ {*}[lmap time $times {
		/ 1.0 $time
	}]]]
	dict set res cv [expr {[dict get $res population_stddev] / [dict get $res arithmetic_mean]}]
}

#>>>
proc bench {name desc args} { #<<<
	variable match
	variable skip
	variable run
	variable skipped
	variable output
	variable current_bench

	# -target_cv		- Run until the coefficient of variation is below this, up to -max_time
	# -max_time 		- Maximum number of seconds to keep running while the cv is converging
	# -min_time			- Keep accumulating samples for at least this many seconds
	# -batch			- The number of samples to take in a tight loop and average to count as a single sample.  "auto" guesses a reasonable value to make a batch take at least 1000 usec.
	# -window			- Consider at most the previous -window measurements for target_cv and the results
	array set opts {
		-setup			{}
		-compare		{}
		-cleanup		{}
		-batch			auto
		-match			exact
		-returnCodes	{ok return}
		-target_cv		{0.0015}
		-min_time		0.0
		-max_time		4.0
		-min_it			30
		-window			30
		-overhead		{}
		-deps			{}
	}
	array set opts $args
	set badargs [lindex [_intersect3 [array names opts] {
		-setup -compare -cleanup -batch -match -result -results -returnCodes -target_cv -min_time -max_time -min_it -window -overhead -deps
	}] 0]

	if {[llength $badargs] > 0} {
		error "Unrecognised arguments: [join $badargs {, }]"
	}

	if {![string match $match $name] || [string match $skip $name]} {
		lappend skipped $name
		return
	}

	set normalized_codes	[lmap e $opts(-returnCodes) {
		switch -- $e {
			ok			{list 0}
			error		{list 1}
			return		{list 2}
			break		{list 3}
			continue	{list 4}
			default		{set e}
		}
	}]

	set make_script {
		{batch script} {
			format {set __bench_i %d; while {[incr __bench_i -1] >= 0} %s} \
				[list $batch] [list $script]
		}
	}

	set variant_stats {}

	set current_bench $name
	_run_if_set $opts(-setup)
	try {
		dict for {variant script} $opts(-compare) {
			try [join [_pick all $variant $opts(-deps)] \n] on error {errmsg options} {
				apply $output notice "Skipping variant $current_bench/$variant: $errmsg"
				continue
			}
			# Verify the first result against -result (if given), and estimate an appropriate batchsize to target a batch time of 1 ms to reduce quantization noise <<<
			set hint	[lindex [time {
				catch {uplevel 1 $script} r o
			}] 0]
			unset -nocomplain expected
			if {[info exists opts(-results)]} {
				set expected	[_pick first! $variant $opts(-results)]
			} elseif {[info exists opts(-result)]} {
				set expected	$opts(-result)
			}
			if {[info exists expected]} {
				#apply $output debug "Verifying expected output for $current_bench/$variant"
				_verify_res $variant $normalized_codes $expected $opts(-match) $r $o
			}

			set single_empty [list uplevel 1 {}]
			set single_ex_s	[list uplevel 1 $script]
			if 1 $single_empty	;# throw the first away
			if 1 $single_ex_s	;# throw the first away

			set single_overhead	[lindex [time $single_empty 1000] 0]
			#puts stderr "single overhead: $single_overhead"

			set est_it	[expr {
				max(1, int(round(
					100.0/$hint
				)))
			}]
			#puts stderr "hint: $hint, est_it: $est_it"
			set extime	[lindex [time $single_ex_s $est_it] 0]
			set extime_comp	[expr {$extime - $single_overhead}]
			#puts stderr "extime: $extime, extime comp: $extime_comp"
			if {$opts(-batch) eq "auto"} {
				if {$extime_comp <= 0} {
					# Can happen for very low overhead
					set batch	10000
				} else {
					set batch	[expr {int(round(max(1, 1000.0/$extime_comp)))}]
				}
				#puts stderr "Guessed batch size of $batch based on sample execution time $extime_comp usec"
			} else {
				set batch	$opts(-batch)
			}
			#>>>

			# Measure the instrumentation overhead to compensate for it <<<
			#apply $output debug "Measuring overhead for $current_bench/$variant"
			set times	{}
			set start	[clock microseconds]	;# Prime [clock microseconds], start var
			set overhead_script	[join [_pick all $variant $opts(-overhead)] \n]
			set bscript	[apply $make_script $batch $overhead_script]
			set est	[lindex [time {uplevel 1 $bscript} 1] 0]
			#apply $output debug "Initial overhead estimate: $est"
			for {set i 0} {$i < int(100000 / $est)} {incr i} {
				set start [clock microseconds]
				uplevel 1 $bscript
				lappend times [- [clock microseconds] $start]
			}
			set overhead	[::tcl::mathfunc::min {*}[lmap e $times {expr {$e / double($batch)}}]]
			#apply $output debug [format {%s Overhead: %.3f usec, mean: %.3f for batch %d: %s} $variant $overhead [expr {double([+ {*}$times]) / ([llength $times]*$batch)}] $batch [list $overhead_script]]
			# Measure the instrumentation overhead to compensate for it >>>

			set cv {data { # Calculate the coefficient of variation of $data <<<
				lassign [::math::statistics::basic-stats $data] \
					arithmetic_mean min max number_of_data sample_stddev sample_var population_stddev population_var

				expr {
					$population_stddev / double($arithmetic_mean)
				}
			}}
			#>>>

			set begin	[clock microseconds]	;# Don't count the first run time or the overhead measurement into the total elapsed time
			set it		0
			set times	{}
			set means	{}
			set cvmeans	{}
			set cvtimes	{}
			set elapsed	0
			set bscript	[apply $make_script $batch $script]
			#puts stderr "bscript $variant: $bscript"
			# Run at least:
			# - -min_it times
			# - for half a second
			# - until the coefficient of variability of the means has fallen below -target_cv, or a max of -max_time seconds
			while {
				[llength $times] < $opts(-min_it) ||
				$elapsed < $opts(-min_time) ||
				($elapsed < $opts(-max_time) && $cvmeans > $opts(-target_cv))
			} {
				set start [clock microseconds]
				uplevel 1 $bscript
				set batchtime	[- [clock microseconds] $start]
				lappend times [expr {
					$batchtime / double($batch) - $overhead
				}]
				set elapsed		[expr {([clock microseconds] - $begin)/1e6}]
				set cvtimes		[lrange $times end-[+ 1 $opts(-window)] end]	;# Consider the last $opts(-window) data in estimating the variation
				lappend means	[expr {[+ {*}$cvtimes]/[llength $cvtimes]}]
				set _cv			[apply $cv $cvtimes]
				set cvmeans		[apply $cv [lrange $means end-[+ 1 $opts(-window)] end]]
				#puts stderr "Got time for $variant batch($batch), batchtime $batchtime usec: [format %.4f [lindex $times end]], elapsed: [format %.3f $elapsed] sec[if {[info exists cvmeans]} {format {, cvmeans: %.3f} $cvmeans}][if {[info exists _cv]} {format {, cv: %.3f} $_cv}], mean: [format %.5f [lindex $means end]]"
			}

			dict set variant_stats $variant [_make_stats $cvtimes]
			dict set variant_stats $variant cvmeans		$cvmeans
			dict set variant_stats $variant cv			[apply $cv $cvtimes]
			dict set variant_stats $variant runtime		$elapsed
			dict set variant_stats $variant it			[llength $cvtimes]
		}

		lappend run $name $desc $variant_stats
	} finally {
		_run_if_set $opts(-cleanup)
		unset current_bench
	}
}; namespace export bench

#>>>
namespace eval display_bench {
	namespace export *
	namespace ensemble create
	namespace path [concat [namespace path] {
		::tcl::mathop
	}]

	proc _heading {txt {char -}} { #<<<
		format {%s %s %s} \
			[string repeat $char 2] \
			$txt \
			[string repeat $char [- 80 5 [string length $txt]]]
	}

	#>>>
	proc short {name desc variant_stats relative {pick median}} { #<<<
		variable output

		teabase_bench::output notice [_heading [format {%s: "%s"} $name $desc]]

		# Gather the union of all the variant names from this and past runs
		set variants	[dict keys $variant_stats]
		foreach {label past_run} $relative {
			foreach past_variant [dict keys $past_run] {
				if {$past_variant ni $variants} {
					lappend variants $past_variant
				}
			}
		}

		# Assemble the tabular data
		lappend rows	[list "" "This run" {*}[dict keys $relative]]
		lappend rows	{*}[lmap variant $variants {
			unset -nocomplain baseline
			set past_stats	[dict values $relative]
			list $variant {*}[lmap stats [list $variant_stats {*}$past_stats] {
				if {![dict exists $stats $variant]} {
					#string cat --
					set _ --
				} else {
					set val		[dict get $stats $variant $pick]
					if {![info exists baseline]} {
						set baseline	$val
						format {%.3f%s} $val [expr {
							[dict exists $stats $variant cv] ? [format { cv:%.1f%%} [expr {100*[dict get $stats $variant cv]}]] : ""
						}]
					} elseif {$baseline == 0} {
						format x%s inf
					} else {
						format {x%.3f%s} [/ $val $baseline] [expr {
							[dict exists $stats $variant cv] ? [format { cv:%.1f%%} [expr {100*[dict get $stats $variant cv]}]] : ""
						}]
					}
				}
			}]
		}]

		# Determine the column widths
		set colsize	{}
		foreach row $rows {
			set cols	[llength $row]
			for {set c 0} {$c < $cols} {incr c} {
				set this_colsize	[string length [lindex $row $c]]
				if {
					![dict exists $colsize $c] ||
					[dict get $colsize $c] < $this_colsize
				} {
					dict set colsize $c $this_colsize
				}
			}
		}

		# Construct the row format description
		set col_fmts	[lmap {c size} $colsize {
			#string cat %${size}s
			set _ %${size}s
		}]
		set fmt	"   [join $col_fmts { | }]"
		set col_count	[llength $col_fmts]

		# Output the row data
		foreach row $rows {
			set data	[list {*}$row {*}[lrepeat [- $col_count [llength $row]] --]]
			teabase_bench::output notice [format $fmt {*}$data]
		}

		teabase_bench::output notice ""
	}

	#>>>
}
proc run_benchmarks {dir args} { #<<<
	variable skipped
	variable run
	variable match
	variable skip
	variable output

	set match				*
	set skip				{}
	set relative			{}
	set display_mode		short
	set display_mode_args	{}
	set rundata				.

	set consume_args [list  \
		count {
			upvar 1 i i args args
			set from	$i
			incr i $count
			lrange $args $from [+ $from $count -1]
		} [namespace current] \
	]

	# Automatically save and compare with the previous run
	set args [list {*}{
		-relative last last
	} {*}$args]

	set i	0
	while {$i < [llength $args]} {
		lassign [apply $consume_args 1] next

		switch -- $next {
			-rundata {
				lassign [apply $consume_args 1] rundata
			}

			-load {
				lassign [apply $consume_args 1] load_script
				namespace eval :: $load_script
			}

			-match {
				lassign [apply $consume_args 1] match
			}

			-skip {
				lassign [apply $consume_args 1] skip
			}

			-relative {
				lassign [apply $consume_args 2] label rel_fn
				set rel_fn	[file join $rundata $rel_fn]
				if {[file readable $rel_fn]} {
					dict set relative $label [_readfile [file join $rundata $rel_fn]]
				}
			}

			-save {
				lassign [apply $consume_args 1] save_fn
				set save_fn	[file join $rundata $save_fn]
			}

			-display {
				lassign [apply $consume_args 1] display_mode
				set display_mode_args	{}
				while {[string index [lindex $args $i] 0] ni {"-" ""}} {
					lappend display_mode_args	[apply $consume_args 1]
				}
			}

			default {
				throw [list BENCH INVALID_ARG $next] \
					"Invalid argument: \"$next\""
			}
		}
	}

	set stats	{}
	foreach f [glob -nocomplain -type f -dir $dir -tails *.bench] {
		try {
			namespace eval _bench_private {namespace path {::teabase_bench}}
			namespace eval _bench_private [list source [file join $dir $f]]
		} finally {
			namespace delete _bench_private
		}
	}

	set save [list {save_fn run} {
		set save_data	$run
		if {[file readable $save_fn]} {
			# If the save file already exists, merge this run's data with it
			# rather than replacing it (keeps old tests that weren't executed
			# in this run)
			set newkeys	[lmap {relname - -} $save_data {set relname}]
			set old		[_readfile $save_fn]
			foreach {relname reldesc relstats} $old {
				if {$relname in $newkeys} continue
				lappend save_data $relname $reldesc $relstats
			}
		}
		_writefile $save_fn $save_data
	} [namespace current]]

	apply $save [file join $rundata last] $run	;# Always save as "last", even if explicitly saving as something else too
	if {[info exists save_fn]} {
		apply $save $save_fn $run
	}

	foreach {name desc variant_stats} $run {
		set relative_stats	{}
		foreach {label relinfo} $relative {
			foreach {relname reldesc relstats} $relinfo {
				if {$relname eq $name} {
					lappend relative_stats $label $relstats
					break
				}
			}
		}
		try {
			display_bench $display_mode $name $desc $variant_stats $relative_stats {*}$display_mode_args
		} trap {TCL LOOKUP SUBCOMMAND} {errmsg options} {
			puts $options
			apply $output error "Invalid display mode: \"$display_mode\""
			exit 1
		} trap {TCL WRONGARGS} {errmsg options} {
			apply $output error "Invalid display mode params: $errmsg"
			exit 1
		}
	}
}

#>>>
}
# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4
