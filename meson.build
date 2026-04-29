if not is_variable('teabase_initialized')
  subdir('init')
endif

inc += include_directories('.')

if tclver_major.to_int() >= 9
  _pkg_so_name = 'tcl9' + meson.project_name()
else
  _pkg_so_name = meson.project_name()
endif

inc += include_directories('pkg_config_h')
if is_variable('tea_genstubs')
  genstubs = custom_target('genstubs',
    output: [meson.project_name() + 'StubInit.c', meson.project_name() + 'Decls.h'],
    command: [
      build_tclsh,
      files('tools/genStubs.tcl'),
      meson.current_build_dir(),
      tea_genstubs[0]
    ],
    install_tag: [false, meson.is_subproject() ? 'deps' : 'runtime'],
    install_dir: [false, pkg_dir],
    env: tea_build_env,
  )

  deps += declare_dependency(sources: genstubs)

  # Build and install stubs library for dependent extensions
  stubs_lib = static_library(meson.project_name() + 'stub',
    tea_genstubs[1],
    dependencies: deps,
    include_directories: inc,
    install:      true,
    install_dir:  pkg_dir,
    install_tag:  meson.is_subproject() ? 'deps' : 'runtime',
  )
endif

pkg_so = shared_module(_pkg_so_name,
  pkg_sources,
  install:      true,
  install_dir:  pkg_dir,
  install_tag:  meson.is_subproject() ? 'deps' : 'runtime',
  dependencies: deps,
  include_directories: inc,
)

_pkg_lib_file = fs.name(pkg_so.full_path())
_pname = meson.project_name()
teaconf.set('PKG_LIB_FILE', _pkg_lib_file)
# Also expose as a C string macro for extensions that need to know their
# own on-disk filename at runtime (e.g. to advertise a link-name matching
# the in-memory copy for consumers that generate and load code dynamically).
conf.set_quoted('PKG_LIB_FILE', _pkg_lib_file)

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
    install:        true,
    install_dir:    pkg_dir,
    install_tag:    meson.is_subproject() ? 'deps' : 'runtime'
  )
endforeach

# Arrange for our the package path to be first in $::auto_path and to be
# able to load any subproject packages.

foreach _dep : tea_bench_deps
  tea_host_env.prepend('TCLLIBPATH', fs.parent(_dep.full_path()), separator: ' ')
endforeach
foreach _dep : tea_test_deps
  tea_host_env.prepend('TCLLIBPATH', fs.parent(_dep.full_path()), separator: ' ')
endforeach
tea_host_env.prepend('TCLLIBPATH', meson.current_build_dir(), separator: ' ')

# Write a sentinel file with the meson build root so that package init
# scripts can locate build-dir or source artifacts.  Not installed.
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

if tclsh.found() and not meson.is_subproject()
  test_env = tea_host_env
  test_env.set('ERROR_ON_FAILURES', '1')

  # Compose the tcltest -load script: source the generated pkgIndex.tcl
  # from the build dir and require the package under test.  Driving
  # tclsh directly (via the thin test_preamble.tcl below — in-process
  # `source`, not a subprocess) means `meson test --test-args` flows
  # through to tcltest's configure, and `meson test --wrapper valgrind`
  # instruments the tclsh running the tests without --trace-children.
  # The -load script itself gets re-used verbatim by tcltest when it
  # spawns per-file subprocesses under `singleProcess 0`, so keep it
  # self-contained (no reliance on anything the preamble sets up).
  #
  # Path and package name are interpolated inside Tcl {...} brace
  # quoting, which is literal except for brace matching — so we only
  # need to backslash-escape any braces they contain.
  #
  # The pkgIndex.tcl file expects `$dir` to be the directory that
  # contains it (Tcl's normal package-require machinery sets this).
  # Source it via [apply] with a dir argument so `$dir` is bound
  # locally to the build dir; otherwise the source fails with
  # "can't read $dir", tcltest swallows it, and the fallback
  # `package require` in loadtdom.tcl silently loads an installed
  # copy of the package instead of the one we just built.
  _pkgdir_esc = meson.current_build_dir() \
    .replace('{', '\\{').replace('}', '\\}')
  _pname_esc = meson.project_name() \
    .replace('{', '\\{').replace('}', '\\}')
  _loadscript = 'apply {dir {' \
              + 'source [file join $dir pkgIndex.tcl]; ' \
              + 'package require -exact {' + _pname_esc + '} ' \
              + meson.project_version() \
              + '}} {' + _pkgdir_esc + '}'

  test('tcltest',
    tclsh,
    args: [
      # test_preamble.tcl splices $env(TESTFLAGS) onto $::argv before
      # sourcing tests/all.tcl, preserving the backwards-compatible way
      # of injecting top-level tcltest options (like -match / -file) —
      # those have to land in argv *before* the test script's own
      # `configure {*}$argv` runs, which is too early for the -load
      # script hook to reach.
      meson.current_source_dir() / 'tools/test_preamble.tcl',
      meson.project_source_root() / 'tests/all.tcl',
      '-load', _loadscript,
    ],
    verbose: true,
    depends: [pkg_so] + tea_test_deps,
    env: test_env,
  )

  benchmark('bench', tclsh,
    depends: [pkg_so] + tea_bench_deps,
    args: meson.project_source_root() / 'teabase/run_bench.tcl',
    verbose: true,
    workdir: meson.project_source_root() / 'bench',
    timeout: 120,
    env: test_env,
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
      env: tea_build_env,
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

subdir('pkg_config_h')

meson.add_devenv(tea_host_env)
