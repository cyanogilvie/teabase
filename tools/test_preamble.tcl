# teabase test launcher preamble.
#
# Invoked as `tclsh test_preamble.tcl <test_script> <tcltest-args...>`.
# Pops <test_script> off $::argv, appends any $env(TESTFLAGS) tokens
# (backwards compatibility with the older runtests.tcl wrapper — a
# whitespace-separated list of tcltest configure options), and sources
# the real test script in-process.
#
# Runs in-process (not a subprocess) so `meson test --test-args` flows
# through to the test script's argv and `meson test --wrapper valgrind`
# follows the tclsh that actually runs the tests (no --trace-children
# needed).  tcltest's per-file subprocesses under `singleProcess 0` are
# spawned with [info nameofexecutable] directly against each .test file,
# so this preamble only participates in the top-level process — TESTFLAGS
# applied here becomes tcltest config, which tcltest then propagates to
# its children via its own Configure-passthrough.

if {[llength $argv] < 1} {
    puts stderr "usage: [info script] <test_script> \[tcltest_args...\]"
    exit 2
}
set argv    [lassign $argv argv0]
if {[info exists env(TESTFLAGS)]} {
    lappend argv {*}$env(TESTFLAGS)
}
if {"-singleproc" ni $argv} {lappend argv -singleproc 1}
# Make [info script] / $argv0 look like the test script was invoked
# directly, so any relative-path idioms in it keep working.
source $argv0
