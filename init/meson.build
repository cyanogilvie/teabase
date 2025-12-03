teabase_initialized = true

pkg_dir = get_option('libdir') / meson.project_name()+'-'+meson.project_version()

tcl_dep = dependency('tcl')
deps += tcl_dep

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

if is_variable('tea_want_shims') and 'tip445' in tea_want_shims
  conf.set10('TIP445_SHIM', not cc.has_function('Tcl_FetchInternalRep', prefix: '#include <tcl.h>', dependencies: tcl_dep))
endif

if not cc.compiles('#include <tcl.h>\nTcl_Size foo=0;', dependencies: tcl_dep)
  conf.set('Tcl_Size',  'int')
endif

if not cc.has_define('MODULE_SCOPE', prefix: '#include <tcl.h>', dependencies: tcl_dep)
  add_project_arguments('-DMODULE_SCOPE=extern',      language: 'c')
  add_project_arguments('-DMODULE_SCOPE=extern "C"',  language: 'cpp')
endif

tclver_full   = tcl_dep.version()
tclver_parts  = tclver_full.split('.')
tclver        = tclver_parts[0] + '.' + tclver_parts[1]
exe_suffix = host_machine.system() == 'windows' ? '.exe' : ''
exec_prefix = tcl_dep.get_variable('exec_prefix')
tclsh_search = []
foreach name : [
  exec_prefix / 'bin/tclsh',
]
  tclsh_search += [
    name + tclver + exe_suffix,
    name + exe_suffix,
  ]
endforeach

tclsh = find_program(tclsh_search, native: false, required: false)
if tclsh.found() and meson.can_run_host_binaries()
  if run_command(tclsh, '../tools/check_ver.tcl', tclver, check: false).returncode() != 0
    error('Tcl version of found tclsh: '+tclsh.full_path()+' does not match the Tcl version of the Tcl dependency: ' + tclver)
  endif
  build_tclsh = tclsh
else
  # Try to find a build machine tclsh
  exe_suffix = build_machine.system() == 'windows' ? '.exe' : ''
  exec_prefix = tcl_dep.get_variable('exec_prefix')
  tclsh_search = []
  foreach name : [
    exec_prefix / 'bin/tclsh',
    'tclsh',
  ]
    tclsh_search += [
      name + tclver + exe_suffix,
      name + exe_suffix,
    ]
  endforeach

  build_tclsh = find_program(tclsh_search, native: true, required: false)
  if build_tclsh.found() and run_command(build_tclsh, '../tools/check_ver.tcl', tclver, check: false).returncode() != 0
    error('Tcl version of found tclsh: '+build_tclsh.full_path()+' does not match the Tcl version of the Tcl dependency: ' + tclver)
  endif
endif
