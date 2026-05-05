project('tcllib',
  version:            '2.0',
  meson_version:      '>=1.3.0',
)
# Pure-Tcl bundle: tcllib ships ~80 sub-packages under modules/, each
# with its own pkgIndex.tcl.  The build phase is a no-op (no compile,
# no codegen); install copies the whole tree so consumers can drop the
# install dir on auto_path.

tcl_dep      = dependency('tcl')
tclver_full  = tcl_dep.version()
tclver_major = tclver_full.split('.')[0]

# Match the upstream tcllib install convention: modules go under
# ${prefix}/lib/tcllib<MAJOR>/.  Tcl's auto_path scanner walks
# subdirectories looking for pkgIndex.tcl, so this layout makes
# `package require uri`, `package require inifile`, etc. resolve
# without needing per-module entries.
tm_install_dir = tcl_dep.get_variable('libdir') / 'tcllib' + meson.project_version()

install_subdir('modules',
  install_dir:    tm_install_dir,
  install_tag:    meson.is_subproject() ? 'deps' : 'runtime',
  strip_directory: true,
)

# Aggregator pkgIndex.tcl at the tcllib root — see comment in the file
# itself.  Without this, auto_path's one-level-deep scan finds
# tcllib2.0/ but never descends into uri/, inifile/, log/, ...
install_data('pkgIndex.tcl',
  install_dir:    tm_install_dir,
  install_tag:    meson.is_subproject() ? 'deps' : 'runtime',
)

tcllib_dep = declare_dependency(
  variables: {
    # Build-time discovery: the source tree's modules/ is auto_path-able
    # as-is, so subproject consumers don't need to install first.
    'tcl_pkg_path': meson.project_source_root() / 'modules',
    'version':      meson.project_version(),
  },
)
meson.override_dependency(meson.project_name(), tcllib_dep)

# vim: foldmethod=marker foldmarker=<<<,>>> shiftwidth=2 expandtab
