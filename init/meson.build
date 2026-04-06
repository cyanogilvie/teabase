teabase_initialized = true

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

hedley_dep = dependency('hedley', version: '>=15', allow_fallback: true, required: false)
if hedley_dep.found()
  deps += hedley_dep
  add_project_arguments('-DHAVE_HEDLEY_H', language: 'c')
  add_project_arguments('-DHAVE_HEDLEY_H', language: 'cpp')
endif

teaconf = conf
teaconf.set('PACKAGE_NAME',    meson.project_name())
teaconf.set('PACKAGE_VERSION', meson.project_version())

conf.set_quoted('PACKAGE_NAME',    meson.project_name())
conf.set_quoted('PACKAGE_VERSION', meson.project_version())

if tcl_dep.type_name() != 'internal'
  # Compile checks require an external dependency
  if is_variable('tea_want_shims') and 'tip445' in tea_want_shims
    conf.set10('TIP445_SHIM', not cc.has_function('Tcl_FetchInternalRep', prefix: '#include <tcl.h>', dependencies: tcl_dep))
  endif

  if is_variable('tea_want_shims') and 'Tcl_GetBytesFromObj' in tea_want_shims
    conf.set10('GETBYTES_SHIM', not cc.has_function('Tcl_GetBytesFromObj', prefix: '#include <tcl.h>', dependencies: tcl_dep))
  endif

  if not cc.compiles('#include <tcl.h>\nTcl_Size foo=0;', dependencies: tcl_dep)
    conf.set('Tcl_Size',  'int')
  endif

  if not cc.has_define('MODULE_SCOPE', prefix: '#include <tcl.h>', dependencies: tcl_dep)
    add_project_arguments('-DMODULE_SCOPE=extern',      language: 'c')
    add_project_arguments('-DMODULE_SCOPE=extern "C"',  language: 'cpp')
  endif

  # Detect libtommath configuration when requested by the consuming project.
  # Set tea_want_tommath = true before subdir('teabase/init') to enable.
  if is_variable('tea_want_tommath') and tea_want_tommath
    tcl_has_internal_tommath = not cc.has_define('TCL_WITH_EXTERNAL_TOMMATH',
      prefix: '#include <tclTomMath.h>', dependencies: tcl_dep)
    tcl_mp_digit_size = cc.sizeof('mp_digit',
      prefix: '#include <tcl.h>\n#include <tclTomMath.h>', dependencies: tcl_dep)
  endif
else
  # Internal subproject provides Tcl 9 source — all features present
  if is_variable('tea_want_tommath') and tea_want_tommath
    tcl_has_internal_tommath = true
    tcl_mp_digit_size = cc.sizeof('size_t')
  endif
  if is_variable('tea_want_shims') and 'tip445' in tea_want_shims
    conf.set10('TIP445_SHIM', false)
  endif

  if is_variable('tea_want_shims') and 'Tcl_GetBytesFromObj' in tea_want_shims
    conf.set10('GETBYTES_SHIM', false)
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
  build_tclsh = tclsh
else
  tclsh = find_program(tclsh_search, native: false, required: false)
  if tclsh.found() and meson.can_run_host_binaries()
    if run_command(tclsh, '../tools/check_ver.tcl', tclver, check: false).returncode() != 0
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
      if run_command(build_tclsh, '../tools/check_ver.tcl', tclver, check: false).returncode() != 0
        error('Tcl version of found tclsh: '+build_tclsh.full_path()+' does not match the Tcl version of the Tcl dependency: ' + tclver)
      endif
    endif
  endif
endif
