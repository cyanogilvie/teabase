if not is_variable('teabase_initialized')
  subdir('init')
endif

inc += include_directories('.')

if tclver_major.to_int() >= 9
  _pkg_so_name = 'tcl9' + meson.project_name()
else
  _pkg_so_name = meson.project_name()
endif

pkg_so = shared_module(_pkg_so_name,
  pkg_sources,
  install:      not meson.is_subproject(),
  install_dir:  pkg_dir,
  dependencies: deps,
  include_directories: inc,
)

_pkg_lib_file = fs.name(pkg_so.full_path())
_pname = meson.project_name()
teaconf.set('PKG_LIB_FILE', _pkg_lib_file)

# TEA convention: Tcl 8 libs are "lib<name>.so", Tcl 9 are "libtcl9<name>.so".
# Both names are always provided so that two builds (one per Tcl major version)
# can be installed side by side in the same package directory.
if tclver_major.to_int() >= 9
  _base = _pkg_lib_file.replace('tcl9' + _pname, _pname)
else
  _base = _pkg_lib_file
endif
teaconf.set('PKG_LIB_FILE8', _base)
teaconf.set('PKG_LIB_FILE9', _base.replace(_pname, 'tcl9' + _pname))

if not is_variable('teaconf_files')
  teaconf_files = []
endif
teaconf_files += files('../pkgIndex.tcl.in')
foreach f : teaconf_files
  fname = fs.name(f)
  configure_file(input: f,
    output: fname.endswith('.in') ? '@BASENAME@' : fname,
    configuration:  teaconf,
    install:        not meson.is_subproject(),
    install_dir:    pkg_dir,
    install_tag:    'runtime',
  )
endforeach

# Write a sentinel file with the meson build root so that package init
# scripts can locate build-dir artifacts.  Not installed.
_builddir_conf = configuration_data()
_builddir_conf.set('BUILDDIR', meson.project_build_root())
_builddir_conf.set('SOURCEDIR', meson.global_source_root())
configure_file(
  output:        '__builddir',
  configuration: _builddir_conf,
  input:         '__builddir.in',
)
configure_file(
  output:        '__srcdir',
  configuration: _builddir_conf,
  input:         '__srcdir.in',
)

# Arrange for our the package path to be first in $::auto_path
devenv = {
  'TCLLIBPATH': meson.current_build_dir(),
}
meson.add_devenv(devenv)

if tclsh.found()
  test_env = {
    'ERROR_ON_FAILURES': '1',
  }
  if tcl_is_internal
    test_env += {'TCL_LIBRARY': tcl_dep.get_variable('source_root') / 'library'}
  endif

  test('tcltest',
    tclsh,
    args: [
      meson.current_source_dir() / 'tools/runtests.tcl',
      meson.project_source_root(),  # source_root
      meson.current_build_dir(),    # pkg_dir
      tclsh.full_path(),            # tclsh
      meson.project_name(),         # package_name
      meson.project_version(),      # package_version
    ],
    verbose: true,
    depends: [pkg_so],
    env: test_env,
  )

  benchmark('bench', tclsh,
    depends: pkg_so,
    args: meson.project_source_root() / 'teabase/run_bench.tcl',
    verbose: true,
    workdir: meson.project_source_root() / 'bench',
    timeout: 120,
    env: devenv,
  )

  vim = find_program('vim', version: '>=8.1', native: true, required: false)
  if not vim.found()
    vim = find_program('nvim', version: '>=0.4', native: true, required: false)
  endif

  if vim.found() and not tcl_is_internal and is_variable('build_tclsh') and build_tclsh.found()
    termdebug_arg = run_command(build_tclsh, meson.current_source_dir() / 'tools/make_termdebug_arg.tcl',
      meson.current_build_dir(),
      meson.project_source_root(),
      tclsh.full_path(),
      meson.project_name(),
      meson.project_version(),
      check: true,
    ).stdout().strip()

    td_conf = configuration_data()
    td_conf.set('TERMDEBUG_ARG', termdebug_arg)

    termdebug_vim = configure_file(
      input: 'termdebug.vim.in',
      output: 'termdebug.vim',
      configuration: td_conf,
    )

    message('Found Vim/Neovim: ' + vim.full_path() + ' for vim-gdb target')
    run_target('vim-gdb',
      command: [vim, '-S', termdebug_vim],
    )
  endif
endif

configure_file(output: 'config.h', configuration: conf)

