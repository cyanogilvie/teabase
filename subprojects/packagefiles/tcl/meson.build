project('tcl', 'c',
  version:          '9.0.3',
  default_options:  ['c_std=c11', 'werror=false', 'warning_level=1'],
)

# Minimal Tcl build: just the stubs library and public headers,
# enough for compiling and linking Tcl extensions.

cc = meson.get_compiler('c')

generic_inc = include_directories('generic')
tommath_inc = include_directories('libtommath')

is_win = host_machine.system() == 'windows'

platform_inc = include_directories(is_win ? 'win' : 'unix')

stub_args = ['-DMP_FIXED_CUTOFFS']

if is_win
  stub_args += [
    '-DCFG_RUNTIME_DLLFILE="tcl90.dll"',
    '-DCFG_RUNTIME_LIBDIR="."',
  ]
else
  stub_args += [
    '-DMODULE_SCOPE=extern',
    '-DCFG_RUNTIME_DLLFILE="libtcl9.0.so"',
    '-DCFG_RUNTIME_LIBDIR="."',
  ]
endif

tclstub = static_library('tclstub',
  'generic/tclStubLib.c',
  'generic/tclStubCall.c',
  'generic/tclStubLibTbl.c',
  'generic/tclTomMathStubLib.c',
  'generic/tclOOStubLib.c',
  include_directories: [generic_inc, tommath_inc, platform_inc],
  c_args: stub_args,
  override_options: ['werror=false', 'warning_level=1'],
)

tcl_dep = declare_dependency(
  include_directories: generic_inc,
  link_with:           tclstub,
  version:             meson.project_version(),
  variables: {
    'libdir':      meson.current_build_dir(),
    'exec_prefix': meson.current_build_dir(),
  },
)
