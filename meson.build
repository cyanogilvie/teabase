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
    install:      true,
    install_tag:  [false, meson.is_subproject() ? 'deps' : 'runtime'],
    install_dir:  [false, pkg_dir],
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
    install_tag:    meson.is_subproject() ? 'deps' : 'runtime',
  )
endforeach

# Arrange for our the package path to be first in $::auto_path and to be
# able to load any subproject packages.

# Mirror this build dir into the host env (so devenv tclsh and
# configure-time run_command can find the just-built package), and
# record the same op so derived test/bench envs replay it.
tea_host_env.prepend('TCLLIBPATH', meson.current_build_dir(), separator: ' ')
tea_host_env_ops += {'var': 'TCLLIBPATH', 'value': meson.current_build_dir()}

# Translate a list of tea_*_deps dependency() objects into env-mod ops:
#   tcl_pkg_path -> TCLLIBPATH (binary `package require` packages)
#   tcl_tm_path  -> TCL<M>_<m>_TM_PATH (pure-Tcl .tm modules)
# Same variable names land in pkg-config (.pc) files and in subproject
# declare_dependency(variables: {...}), so this works uniformly for
# system installs and fallbacks. Deps exporting neither (e.g. plain C
# libraries like libtcc) are silently skipped.
_tm_path_var = 'TCL' + tclver_major + '_' + tclver_minor + '_TM_PATH'
_test_dep_ops  = []
_bench_dep_ops = []
foreach _dep : tea_test_deps
  _pkg_path = _dep.get_variable('tcl_pkg_path', default_value: '')
  if _pkg_path != ''
    _test_dep_ops += {'var': 'TCLLIBPATH', 'value': _pkg_path}
  endif
  _tm_path = _dep.get_variable('tcl_tm_path', default_value: '')
  if _tm_path != ''
    _test_dep_ops += {'var': _tm_path_var, 'value': _tm_path}
  endif
endforeach
foreach _dep : tea_bench_deps
  _pkg_path = _dep.get_variable('tcl_pkg_path', default_value: '')
  if _pkg_path != ''
    _bench_dep_ops += {'var': 'TCLLIBPATH', 'value': _pkg_path}
  endif
  _tm_path = _dep.get_variable('tcl_tm_path', default_value: '')
  if _tm_path != ''
    _bench_dep_ops += {'var': _tm_path_var, 'value': _tm_path}
  endif
endforeach

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
  # Build test_env and bench_env as fresh environment() objects rather
  # than aliasing tea_host_env. meson stores the env arg to test() by
  # reference (not as a snapshot), so any later modification — like
  # adding bench-only deps for benchmark() — would leak back into the
  # already-registered test(). Replaying tea_host_env_ops keeps base
  # PATH/TCLLIBPATH/TCL_LIBRARY content intact in both, while each env
  # gets only the dep additions appropriate for its scope.
  test_env  = environment()
  foreach _op : tea_host_env_ops + _test_dep_ops
    if 'op' in _op and _op['op'] == 'set'
      test_env.set(_op['var'], _op['value'])
    else  # 'prepend'
      if _op['var'] == 'TCLLIBPATH'
        test_env.prepend(_op['var'], _op['value'], separator: ' ')
      else
        test_env.prepend(_op['var'], _op['value'])
      endif
    endif
  endforeach
  test_env.set('ERROR_ON_FAILURES', '1')

  bench_env = environment()
  foreach _op : tea_host_env_ops + _test_dep_ops + _bench_dep_ops
    if 'op' in _op and _op['op'] == 'set'
      bench_env.set(_op['var'], _op['value'])
    else  # 'prepend'
      if _op['var'] == 'TCLLIBPATH'
        bench_env.prepend(_op['var'], _op['value'], separator: ' ')
      else
        bench_env.prepend(_op['var'], _op['value'])
      endif
    endif
  endforeach
  bench_env.set('ERROR_ON_FAILURES', '1')

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

  _test_deps_met = true
  foreach _dep : tea_test_deps
    if not _dep.found()
      _test_deps_met = false
    endif
  endforeach
  if _test_deps_met
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
      depends: [pkg_so] + tea_extra_depends,
      env: test_env,
    )
  endif

  _bench_deps_met = true
  foreach _dep : tea_bench_deps
    if not _dep.found()
      _bench_deps_met = false
    endif
  endforeach
  if _bench_deps_met
    benchmark('bench', tclsh,
      depends: [pkg_so] + tea_extra_depends + tea_bench_extra_depends,
      args: meson.project_source_root() / 'teabase/run_bench.tcl',
      verbose: true,
      workdir: meson.project_source_root() / 'bench',
      timeout: 120,
      env: bench_env,
    )
  endif

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

# Fold test/bench dep additions into tea_host_env now that test/bench
# environments have been built fresh (so they aren't affected by these
# late mutations). devenv-launched tclsh ought to see the same package
# search paths as bench_env — important for subproject-fallback deps
# that aren't system-installed.
foreach _op : _test_dep_ops + _bench_dep_ops
  if 'op' in _op and _op['op'] == 'set'
    tea_host_env.set(_op['var'], _op['value'])
  else
    if _op['var'] == 'TCLLIBPATH'
      tea_host_env.prepend(_op['var'], _op['value'], separator: ' ')
    else
      tea_host_env.prepend(_op['var'], _op['value'])
    endif
  endif
endforeach

meson.add_devenv(tea_host_env)
