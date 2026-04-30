teabase_initialized = true

if not is_variable('deps')
  deps = []
endif

if not is_variable('tea_want_shims')
  tea_want_shims = []
endif

# Tcl-package dependencies needed at test/benchmark time, expressed as
# meson dependency() objects. teabase reads `tcl_pkg_path` (binary
# packages — added to TCLLIBPATH) and `tcl_tm_path` (pure-Tcl .tm
# modules — added to TCL<M>_<m>_TM_PATH) from each dep's variables;
# same names are used in .pc files and in declare_dependency(variables:)
# subproject fallbacks. Any dep that exports neither is ignored.
#
# tea_bench_deps is conceptually additive to tea_test_deps (benchmarks
# inherit the test deps). Keeping them separate lets a project add
# heavyweight bench-only fixtures that aren't fetched/built when only
# `meson test` runs.
if not is_variable('tea_test_deps')
  tea_test_deps = []
endif

if not is_variable('tea_bench_deps')
  tea_bench_deps = []
endif

# Extra build targets (executables, custom_targets, shared_modules ...)
# that must exist before `meson test` runs. For tools accessed via
# tea_host_env's PATH (re2c, packcc, ...) and for subproject-fallback
# Tcl packages whose underlying targets would otherwise not get built
# (tea_test_deps holds dependency() objects, which can't appear in a
# test()'s `depends:` list).
#
# tea_bench_extra_depends is the bench-only counterpart, also additive:
# `meson test --benchmark` builds tea_extra_depends + tea_bench_extra_depends.
if not is_variable('tea_extra_depends')
  tea_extra_depends = []
endif

if not is_variable('tea_bench_extra_depends')
  tea_bench_extra_depends = []
endif

# Live host env (used for configure-time run_command and meson.add_devenv).
# Mutations to tea_host_env are mirrored into tea_host_env_ops so we can
# replay the same modifications onto fresh environment objects later.
# meson's environment() can't be cloned and stores a reference (not a
# snapshot) when passed to test() — without an op log there's no way to
# build distinct test_env / bench_env objects with overlapping content.
# Each entry: {'op': 'set' | 'prepend', 'var': str, 'value': str}
if not is_variable('tea_host_env')
  tea_host_env     = environment()
endif
if not is_variable('tea_host_env_ops')
  tea_host_env_ops = []
endif

if not is_variable('tea_build_env')
  tea_build_env = environment()
endif

add_project_arguments('-DHAVE_CONFIG_H=1', language: 'c')

tcl_dep = dependency('tcl')
if tcl_dep.type_name() == 'internal'
  pkg_dir = 'lib' / meson.project_name()+'-'+meson.project_version()
else
  pkg_dir = tcl_dep.get_variable('libdir') / meson.project_name()+'-'+meson.project_version()
endif

# Use tcl_dep for compile args (includes) only, link against stubs library
deps += tcl_dep.partial_dependency(compile_args: true, includes: true)
if tcl_dep.type_name() == 'internal'
  # Subproject fallback: stubs library is already part of tcl_dep
  deps += tcl_dep.partial_dependency(links: true)
else
  deps += cc.find_library('tclstub', dirs: [tcl_dep.get_variable('libdir')])
endif
add_project_arguments('-DUSE_TCL_STUBS=1', language: 'c')
add_project_arguments('-DUSE_TCL_STUBS=1', language: 'cpp')

if 'hedley' in tea_want_shims
  hedley_dep = dependency('hedley', version: '>=15', allow_fallback: true, required: false)
  if hedley_dep.found()
    deps += hedley_dep
    add_project_arguments('-DHAVE_HEDLEY_H', language: 'c')
    add_project_arguments('-DHAVE_HEDLEY_H', language: 'cpp')
  endif
endif

teaconf = conf
teaconf.set('PACKAGE_NAME',    meson.project_name())
teaconf.set('PACKAGE_VERSION', meson.project_version())

conf.set_quoted('PACKAGE_NAME',    meson.project_name())
conf.set_quoted('PACKAGE_VERSION', meson.project_version())

if tcl_dep.type_name() != 'internal'
  # Compile checks require an external dependency
  if 'tip445' in tea_want_shims
    conf.set10('TIP445_SHIM', not cc.has_function('Tcl_FetchInternalRep', prefix: '#include <tcl.h>', dependencies: tcl_dep))
  endif

  if 'Tcl_GetBytesFromObj' in tea_want_shims
    conf.set10('GETBYTES_SHIM', not cc.has_function('Tcl_GetBytesFromObj', prefix: '#include <tcl.h>', dependencies: tcl_dep))
  endif

  if not cc.compiles('#include <tcl.h>\nTcl_Size foo=0;', dependencies: tcl_dep)
    conf.set('Tcl_Size',  'int')
  endif
  if not cc.has_header_symbol('tcl.h', 'TCL_SIZE_MODIFIER', dependencies: tcl_dep)
    conf.set('TCL_SIZE_MODIFIER', '""')
  endif

  if not cc.has_define('MODULE_SCOPE', prefix: '#include <tcl.h>', dependencies: tcl_dep)
    add_project_arguments('-DMODULE_SCOPE=extern',      language: 'c')
    add_project_arguments('-DMODULE_SCOPE=extern "C"',  language: 'cpp')
  endif

  # Detect libtommath configuration when requested by the consuming project.
  # Set tea_want_tommath = true before subdir('teabase/init') to enable.
  if is_variable('tea_want_tommath') and tea_want_tommath
    # tclTomMath.h may #include "tommath.h" which may not be installed
    # even when Tcl has internal tommath.  Probe first to avoid a hard
    # error from has_define / sizeof.
    _tommath_hdr_ok = cc.compiles(
      '#include <tcl.h>\n#include <tclTomMath.h>\nmp_digit d;',
      name: 'tclTomMath.h usable',
      dependencies: tcl_dep,
    )
    if _tommath_hdr_ok
      tcl_has_internal_tommath = not cc.has_define('TCL_WITH_EXTERNAL_TOMMATH',
        prefix: '#include <tclTomMath.h>', dependencies: tcl_dep)
      tcl_mp_digit_size = cc.sizeof('mp_digit',
        prefix: '#include <tcl.h>\n#include <tclTomMath.h>', dependencies: tcl_dep)
    else
      # Header broken or missing tommath.h — assume internal tommath
      tcl_has_internal_tommath = true
      tcl_mp_digit_size = cc.sizeof('size_t')
    endif
  endif
else
  # Internal subproject provides Tcl 9 source — all features present
  if is_variable('tea_want_tommath') and tea_want_tommath
    tcl_has_internal_tommath = true
    tcl_mp_digit_size = cc.sizeof('size_t')
  endif
  if 'tip445' in tea_want_shims
    conf.set10('TIP445_SHIM', false)
  endif

  if 'Tcl_GetBytesFromObj' in tea_want_shims
    conf.set10('GETBYTES_SHIM', false)
  endif
endif

# defer.h support: set tea_want_defer = true before subdir('teabase/init') to
# enable #include "teabase/defer.h". Detects either native _Defer (clang 22+,
# with or without -fdefer-ts), or GCC nested-function + cleanup-attribute
# polyfill. Errors if neither is available.
if is_variable('tea_want_defer') and tea_want_defer
  _defer_native = '''
    int main(void) {
      int x = 0;
      _Defer { x = 1; }
      return x;
    }
  '''
  _defer_polyfill = '''
    void cleanup(int *p) { (void)p; }
    int main(void) {
      __attribute__((__cleanup__(cleanup))) int x;
      auto void f(int*);
      inline auto void f(__attribute__((__unused__)) int *p) {}
      return 0;
    }
  '''
  if cc.compiles(_defer_native, name: 'native _Defer')
    conf.set10('HAVE_NATIVE_DEFER', true)
  elif cc.compiles(_defer_native, args: ['-fdefer-ts'], name: 'native _Defer (-fdefer-ts)')
    conf.set10('HAVE_NATIVE_DEFER', true)
    add_project_arguments('-fdefer-ts', language: 'c')
  elif cc.compiles(_defer_polyfill, name: 'GCC defer polyfill support')
    conf.set10('HAVE_DEFER_POLYFILL', true)
  else
    error('No defer support: need _Defer (clang 22+ with -fdefer-ts) or GCC 9+ nested functions')
  endif
endif

tclver_full   = tcl_dep.version()
tclver_parts  = tclver_full.split('.')
tclver_major = tclver_parts[0]
tclver_minor = tclver_parts[1]
# Strip alpha/beta suffixes
tclver_minor = tclver_minor.split('a')[0].split('b')[0].split('rc')[0]
tclver = tclver_major + '.' + tclver_minor
exe_suffix = host_machine.system() == 'windows' ? '.exe' : ''
exec_prefix = tcl_dep.get_variable('exec_prefix')
tclsh_search = []
foreach name : [
  exec_prefix / 'bin/tclsh',
  exec_prefix / 'tclsh',
  'tclsh',
]
  tclsh_search += [
    name + tclver + exe_suffix,
    name + exe_suffix,
  ]
endforeach

tcl_is_internal = tcl_dep.type_name() == 'internal'

if tcl_is_internal
  # Get the host tclsh directly from the subproject.  For tests this
  # runs via the exe_wrapper in cross builds.  build_tclsh (used in
  # run_command at configure time) can't be a compiled target, so it's
  # only set in native builds where the subproject's tclsh IS a native
  # program.
  tcl_subproj = subproject('tcl')
  tclsh = tcl_subproj.get_variable('tclsh_exe')
  _tcl_lib  = tcl_subproj.get_variable('tcl_library')
  _tcl_pre  = tcl_subproj.get_variable('exec_prefix')
  tea_host_env.set('TCL_LIBRARY', _tcl_lib)
  tea_host_env.prepend('PATH', _tcl_pre)
  tea_host_env_ops += [
    {'op': 'set', 'var': 'TCL_LIBRARY', 'value': _tcl_lib},
    {             'var': 'PATH',        'value': _tcl_pre},
  ]
  build_tclsh = tclsh
  tea_build_env.set('TCL_LIBRARY', _tcl_lib)
  tea_build_env.prepend('PATH', _tcl_pre)
else
  tclsh = find_program(tclsh_search, native: false, required: false)
  if tclsh.found() and meson.can_run_host_binaries()
    if run_command(tclsh, '../tools/check_ver.tcl', tclver, check: false, env: tea_host_env).returncode() != 0
      error('Tcl version of found tclsh: '+tclsh.full_path()+' does not match the Tcl version of the Tcl dependency: ' + tclver)
    endif
    build_tclsh = tclsh
  endif

  if not is_variable('build_tclsh')
    # Try to find a build machine tclsh for configure-time scripts
    exe_suffix = build_machine.system() == 'windows' ? '.exe' : ''
    exec_prefix = tcl_dep.get_variable('exec_prefix')
    tclsh_search = []
    foreach name : [
      exec_prefix / 'bin/tclsh',
      exec_prefix / 'tclsh',
      'tclsh',
    ]
      tclsh_search += [
        name + tclver + exe_suffix,
        name + exe_suffix,
      ]
    endforeach

    build_tclsh = find_program(tclsh_search, native: true, required: false)
    if build_tclsh.found()
      if run_command(build_tclsh, '../tools/check_ver.tcl', tclver, check: false, env: tea_build_env).returncode() != 0
        error('Tcl version of found tclsh: '+build_tclsh.full_path()+' does not match the Tcl version of the Tcl dependency: ' + tclver)
      endif
    endif
  endif

  if tclsh.found()
    _tclsh_dir = fs.parent(tclsh.full_path())
    tea_host_env.prepend('PATH', _tclsh_dir)
    tea_host_env_ops += {'var': 'PATH', 'value': _tclsh_dir}
  endif
  if build_tclsh.found()
    tea_build_env.prepend('PATH', fs.parent(build_tclsh.full_path()))
  endif
endif
