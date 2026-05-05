# Aggregator pkgIndex for tcllib's modules tree.
#
# Each tcllib subpackage (uri/, inifile/, log/, ...) ships its own
# pkgIndex.tcl, but Tcl's tclPkgUnknown only walks one level below
# auto_path entries.  When this file is installed to
# ${libdir}/tcllib<VER>/pkgIndex.tcl, auto_path traversal will pick
# up THIS file (one level under ${libdir}) but not the subpackage
# pkgIndexes (two levels deep).
#
# Workaround: append our own directory to auto_path here.  Tcl's
# tclPkgUnknown re-syncs against auto_path mid-scan, so this triggers
# another pass that walks our subdirectories and finds the
# subpackage pkgIndex.tcl files.
if {[lsearch -exact $::auto_path $dir] == -1} {
    lappend ::auto_path $dir
}
