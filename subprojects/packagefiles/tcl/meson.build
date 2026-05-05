project('tcl', 'c',
  version:          '9.0.3',
  default_options:  ['c_std=gnu11', 'werror=false', 'warning_level=1'],
)

cc = meson.get_compiler('c')

is_win = host_machine.system() == 'windows'

generic_inc     = include_directories('generic')
compat_zlib_inc = include_directories('compat/zlib', 'compat/zlib/contrib/minizip')
platform_inc    = include_directories(is_win ? 'win' : 'unix')

override_opts = ['werror=false', 'warning_level=1']

# --- Dependencies ---

zlib_dep = dependency('zlib', required: false)
tommath_dep = dependency('libtommath', version: '>=1.3.0', allow_fallback: true)

if not zlib_dep.found()
  # Use Tcl's bundled zlib sources
  bundled_zlib = static_library('tclzlib',
    'compat/zlib/adler32.c',
    'compat/zlib/compress.c',
    'compat/zlib/crc32.c',
    'compat/zlib/deflate.c',
    'compat/zlib/infback.c',
    'compat/zlib/inffast.c',
    'compat/zlib/inflate.c',
    'compat/zlib/inftrees.c',
    'compat/zlib/trees.c',
    'compat/zlib/uncompr.c',
    'compat/zlib/zutil.c',
    include_directories:  compat_zlib_inc,
    override_options:     override_opts,
  )
  zlib_dep = declare_dependency(
    link_with:            bundled_zlib,
    include_directories:  compat_zlib_inc,
  )
endif

# --- Common compile args ---

dll_name = is_win ? 'tcl90.dll' : 'libtcl9.0.so'


incdir      = meson.project_source_root() / 'generic'
builddir    = meson.current_build_dir()
tcl_library = meson.project_source_root() / 'library'
tcl_args = [
  '-DBUILD_tcl',
  '-DCFG_INSTALL_BINDIR="' + builddir + '"',
  '-DCFG_INSTALL_DOCDIR="' + builddir + '"',
  '-DCFG_INSTALL_INCDIR="' + incdir + '"',
  '-DCFG_INSTALL_LIBDIR="' + builddir + '"',
  '-DCFG_INSTALL_SCRDIR="' + tcl_library + '"',
  '-DCFG_RUNTIME_BINDIR="' + builddir + '"',
  '-DCFG_RUNTIME_DLLFILE="' + dll_name + '"',
  '-DCFG_RUNTIME_DOCDIR="' + builddir + '"',
  '-DCFG_RUNTIME_INCDIR="' + incdir + '"',
  '-DCFG_RUNTIME_LIBDIR="' + builddir + '"',
  '-DCFG_RUNTIME_SCRDIR="' + tcl_library + '"',
  '-DMP_FIXED_CUTOFFS',
  '-DMP_PREC=4',
  '-DPACKAGE_NAME="tcl"',
  '-DPACKAGE_VERSION="' + meson.project_version() + '"',
  '-DTCL_WITH_EXTERNAL_TOMMATH',
]

if is_win
  if cc.get_id() != 'msvc'
    tcl_args += '-DHAVE_NO_SEH=1'
  endif
  tcl_args += '-DUNICODE'
  tcl_args += '-D_UNICODE'
  tcl_args += '-DTCL_CFGVAL_ENCODING="utf-8"'
  tcl_args += '-DSTDC_HEADERS=1'
  tcl_args += '-DZIPFS_BUILD=1'
elif not is_win
  if cc.has_function_attribute('visibility')
    tcl_args += '-DMODULE_SCOPE=extern __attribute__((__visibility__("hidden")))'
    tcl_args += '-DHAVE_HIDDEN=1'
  else
    tcl_args += '-DMODULE_SCOPE=extern'
  endif
  tcl_args += '-D_GNU_SOURCE'
  tcl_args += '-D_REENTRANT=1'
  tcl_args += '-D_THREAD_SAFE=1'

  foreach h : [
    'inttypes.h',
    'langinfo.h',
    'stdint.h',
    'strings.h',
    'sys/epoll.h',
    'sys/eventfd.h',
    'sys/ioctl.h',
    'sys/param.h',
    'sys/stat.h',
    'sys/time.h',
    'termios.h',
    'unistd.h',
  ]
    if cc.has_header(h)
      tcl_args += '-DHAVE_' + h.underscorify().to_upper() + '=1'
    endif
  endforeach

  foreach pair : [
    ['cfmakeraw',    ''],
    ['cpuid',        ''],
    ['freeaddrinfo', ''],
    ['fts',          ''],
    ['gai_strerror', ''],
    ['getaddrinfo',  ''],
    ['getcwd',       ''],
    ['getnameinfo',  ''],
    ['gmtime_r',     ''],
    ['localtime_r',  ''],
    ['mkstemp',      ''],
    ['mkstemps',     ''],
    ['posix_spawnp', ''],
    ['pselect',      ''],
    ['vfork',        ''],
    ['waitpid',      ''],
  ]
    if cc.has_function(pair[0])
      tcl_args += '-DHAVE_' + pair[0].to_upper() + '=1'
    endif
  endforeach

  if cc.has_header_symbol('sys/epoll.h', 'epoll_create')
    tcl_args += '-DNOTIFIER_EPOLL=1'
  endif
  if cc.has_function('eventfd')
    tcl_args += '-DHAVE_EVENTFD=1'
  endif
  if cc.has_member('struct stat', 'st_blocks', prefix: '#include <sys/stat.h>')
    tcl_args += '-DHAVE_STRUCT_STAT_ST_BLOCKS=1'
  endif
  if cc.has_member('struct stat', 'st_blksize', prefix: '#include <sys/stat.h>')
    tcl_args += '-DHAVE_STRUCT_STAT_ST_BLKSIZE=1'
  endif
  if cc.has_member('struct tm', 'tm_gmtoff', prefix: '#include <time.h>')
    tcl_args += '-DHAVE_TM_GMTOFF=1'
  endif
  if cc.compiles('extern int timezone;\nint main(){return timezone;}')
    tcl_args += '-DHAVE_TIMEZONE_VAR=1'
  endif
  if cc.has_type('intptr_t', prefix: '#include <stdint.h>')
    tcl_args += '-DHAVE_INTPTR_T=1'
  endif
  if cc.has_type('uintptr_t', prefix: '#include <stdint.h>')
    tcl_args += '-DHAVE_UINTPTR_T=1'
  endif
  if cc.sizeof('long') >= 8
    tcl_args += '-DTCL_WIDE_INT_IS_LONG=1'
  endif

  net_prefix = '#include <sys/types.h>\n#include <sys/socket.h>\n#include <netdb.h>'
  foreach s : ['addrinfo', 'in6_addr', 'sockaddr_in6', 'sockaddr_storage']
    if cc.has_type('struct ' + s, prefix: net_prefix)
      tcl_args += '-DHAVE_STRUCT_' + s.to_upper() + '=1'
    endif
  endforeach

  if cc.has_function('pthread_attr_setstacksize', prefix: '#include <pthread.h>')
    tcl_args += '-DHAVE_PTHREAD_ATTR_SETSTACKSIZE=1'
  endif
  if cc.has_function('pthread_atfork', prefix: '#include <pthread.h>')
    tcl_args += '-DHAVE_PTHREAD_ATFORK=1'
  endif

  tcl_args += '-DHAVE_BLKCNT_T=1'
  tcl_args += '-DHAVE_SIGNED_CHAR=1'
  tcl_args += '-D_LARGEFILE64_SOURCE=1'
  tcl_args += '-DNO_UNION_WAIT=1'
  tcl_args += '-DSTDC_HEADERS=1'
  tcl_args += '-DTCL_CFGVAL_ENCODING="utf-8"'
  tcl_args += '-DTCL_LIBRARY="' + tcl_library + '"'
  tcl_args += '-DTCL_PACKAGE_PATH="' + tcl_library + '"'
  tcl_args += '-DTCL_SHLIB_EXT=".so"'
  tcl_args += '-DTCL_UNLOAD_DLLS=1'
  tcl_args += '-DZIPFS_BUILD=1'
  if cc.has_function('dladdr', prefix: '#define _GNU_SOURCE\n#include <dlfcn.h>')
    tcl_args += '-DHAVE_DLADDR=1'
  endif
endif

fs = import('fs')

# --- Generated headers ---

# tclUuid.h — derived from fossil manifest.uuid
manifest_uuid = fs.read('manifest.uuid').strip()
uuid_conf = configuration_data()
uuid_conf.set('UUID', manifest_uuid)
tclUuid_h = configure_file(
  input:          'tclUuid.h.in',
  output:         'tclUuid.h',
  configuration:  uuid_conf,
)

# --- Source files ---

generic_sources = files(
  'generic/regcomp.c',
  'generic/regerror.c',
  'generic/regexec.c',
  'generic/regfree.c',
  'generic/tclAlloc.c',
  'generic/tclArithSeries.c',
  'generic/tclAssembly.c',
  'generic/tclAsync.c',
  'generic/tclBasic.c',
  'generic/tclBinary.c',
  'generic/tclCkalloc.c',
  'generic/tclClock.c',
  'generic/tclClockFmt.c',
  'generic/tclCmdAH.c',
  'generic/tclCmdIL.c',
  'generic/tclCmdMZ.c',
  'generic/tclCompCmds.c',
  'generic/tclCompCmdsGR.c',
  'generic/tclCompCmdsSZ.c',
  'generic/tclCompExpr.c',
  'generic/tclCompile.c',
  'generic/tclConfig.c',
  'generic/tclDate.c',
  'generic/tclDictObj.c',
  'generic/tclDisassemble.c',
  'generic/tclEncoding.c',
  'generic/tclEnsemble.c',
  'generic/tclEnv.c',
  'generic/tclEvent.c',
  'generic/tclExecute.c',
  'generic/tclFCmd.c',
  'generic/tclFileName.c',
  'generic/tclGet.c',
  'generic/tclHash.c',
  'generic/tclHistory.c',
  'generic/tclIcu.c',
  'generic/tclIndexObj.c',
  'generic/tclInterp.c',
  'generic/tclIO.c',
  'generic/tclIOCmd.c',
  'generic/tclIOGT.c',
  'generic/tclIORChan.c',
  'generic/tclIORTrans.c',
  'generic/tclIOSock.c',
  'generic/tclIOUtil.c',
  'generic/tclLink.c',
  'generic/tclListObj.c',
  'generic/tclLiteral.c',
  'generic/tclLoad.c',
  'generic/tclMain.c',
  'generic/tclNamesp.c',
  'generic/tclNotify.c',
  'generic/tclObj.c',
  'generic/tclOptimize.c',
  'generic/tclPanic.c',
  'generic/tclParse.c',
  'generic/tclPathObj.c',
  'generic/tclPipe.c',
  'generic/tclPkg.c',
  'generic/tclPkgConfig.c',
  'generic/tclPosixStr.c',
  'generic/tclPreserve.c',
  'generic/tclProc.c',
  'generic/tclProcess.c',
  'generic/tclRegexp.c',
  'generic/tclResolve.c',
  'generic/tclResult.c',
  'generic/tclScan.c',
  'generic/tclStrIdxTree.c',
  'generic/tclStringObj.c',
  'generic/tclStrToD.c',
  'generic/tclStubInit.c',
  'generic/tclThreadAlloc.c',
  'generic/tclThread.c',
  'generic/tclThreadJoin.c',
  'generic/tclThreadStorage.c',
  'generic/tclTimer.c',
  'generic/tclTomMathInterface.c',
  'generic/tclTrace.c',
  'generic/tclUtf.c',
  'generic/tclUtil.c',
  'generic/tclVar.c',
  'generic/tclZipfs.c',
  'generic/tclZlib.c',
)

oo_sources = files(
  'generic/tclOOBasic.c',
  'generic/tclOO.c',
  'generic/tclOOCall.c',
  'generic/tclOODefineCmds.c',
  'generic/tclOOInfo.c',
  'generic/tclOOMethod.c',
  'generic/tclOOProp.c',
  'generic/tclOOStubInit.c',
)

if is_win
  platform_sources = files(
    'win/tclWin32Dll.c',
    'win/tclWinChan.c',
    'win/tclWinConsole.c',
    'win/tclWinError.c',
    'win/tclWinFCmd.c',
    'win/tclWinFile.c',
    'win/tclWinInit.c',
    'win/tclWinLoad.c',
    'win/tclWinNotify.c',
    'win/tclWinPipe.c',
    'win/tclWinSerial.c',
    'win/tclWinSock.c',
    'win/tclWinThrd.c',
    'win/tclWinTime.c',
  )
  # tclWinPanic.c provides Tcl_ConsolePanic — linked into both the DLL
  # and tclsh directly (the symbol isn't dllexport'd)
  platform_sources += files('win/tclWinPanic.c')
  tclsh_sources = files('win/tclAppInit.c', 'win/tclWinPanic.c')
  platform_deps = [
    cc.find_library('ws2_32'),
    cc.find_library('netapi32'),
    cc.find_library('user32'),
    cc.find_library('userenv'),
  ]
  tclsh_link_args = cc.get_id() != 'msvc' ? ['-mconsole', '-municode'] : []
else
  platform_sources = files(
    'unix/tclEpollNotfy.c',
    'unix/tclKqueueNotfy.c',
    'unix/tclLoadDl.c',
    'unix/tclSelectNotfy.c',
    'unix/tclUnixChan.c',
    'unix/tclUnixCompat.c',
    'unix/tclUnixEvent.c',
    'unix/tclUnixFCmd.c',
    'unix/tclUnixFile.c',
    'unix/tclUnixInit.c',
    'unix/tclUnixPipe.c',
    'unix/tclUnixSock.c',
    'unix/tclUnixThrd.c',
    'unix/tclUnixTime.c',
  )
  tclsh_sources = files('unix/tclAppInit.c')
  platform_deps = [
    cc.find_library('dl',      required: false),
    cc.find_library('pthread', required: false),
    cc.find_library('m',       required: false),
  ]
endif

# --- Shared library ---

build_inc = include_directories('.')

tcllib = shared_library(
  is_win ? 'tcl90' : 'tcl9.0',
  generic_sources, oo_sources, platform_sources,
  include_directories:    [generic_inc, compat_zlib_inc, platform_inc, build_inc],
  c_args:                 tcl_args,
  dependencies:           [zlib_dep, tommath_dep] + platform_deps,
  override_options:       override_opts,
  name_prefix:            is_win ? '' : 'lib',
  gnu_symbol_visibility:  is_win ? 'default' : 'hidden',
  install:                true,
  # Plain `${prefix}/lib`, not get_option('libdir') — Tcl's own
  # autoconf install convention is to ignore Debian-style multiarch
  # subdirs.  Downstream Tcl extensions discover libtcl9 via the
  # tcl.pc / declare_dependency machinery, not via ld config, so it's
  # cleaner to keep the layout flat regardless of host triple.
  install_dir:            'lib',
  install_tag:            meson.is_subproject() ? 'deps' : 'runtime',
)

# --- Stubs library ---

stub_args = [
  '-DCFG_RUNTIME_BINDIR="' + builddir + '"',
  '-DCFG_RUNTIME_DLLFILE="' + dll_name + '"',
  '-DCFG_RUNTIME_LIBDIR="' + builddir + '"',
  '-DMP_FIXED_CUTOFFS',
  '-DTCL_WITH_EXTERNAL_TOMMATH',
]
if not is_win
  stub_args += '-DMODULE_SCOPE=extern'
endif

tclstub = static_library('tclstub',
  'generic/tclOOStubLib.c',
  'generic/tclStubCall.c',
  'generic/tclStubLib.c',
  'generic/tclStubLibTbl.c',
  'generic/tclTomMathStubLib.c',
  include_directories:  [generic_inc, platform_inc],
  dependencies:         tommath_dep.partial_dependency(compile_args: true, includes: true),
  c_args:               stub_args,
  override_options:     override_opts,
  install:              true,     # Needed to prevent meson creating a thin archive
  install_dir:          'lib',
  install_tag:          'deps',
)

# --- ZipFS: embed library scripts ---

exe_suffix  = is_win ? '.exe' : ''
zip_prog    = find_program('zip', native: true)
srcroot     = meson.project_source_root()
outdir      = meson.current_build_dir()

zip_output = 'libtcl@0@.zip'.format(meson.project_version())

tcl_zip = custom_target('tcl-zipfs',
  output: zip_output,
  input: tcllib,
  command: [
    'sh', '-c',
    'set -e && ' +
    'rm -rf @0@/libtcl.vfs && '.format(outdir) +
    'mkdir -p @0@/libtcl.vfs/tcl_library && '.format(outdir) +
    'cp -a @0@/library/* @1@/libtcl.vfs/tcl_library/ && '.format(srcroot, outdir) +
    'if [ -f @0@/libtcl.vfs/tcl_library/manifest.txt ]; then '.format(outdir) +
      'mv @0@/libtcl.vfs/tcl_library/manifest.txt @0@/libtcl.vfs/tcl_library/pkgIndex.tcl; '.format(outdir) +
    'fi && ' +
    'cd @0@/libtcl.vfs && @1@ -rq @2@/@3@ *'.format(outdir, zip_prog.full_path(), outdir, zip_output),
  ],
)

# --- tclsh ---

tclsh_name = 'tclsh' + meson.project_version().split('.')[0] + '.' + meson.project_version().split('.')[1]

tclsh_exe = executable(tclsh_name + '-base',
  tclsh_sources,
  include_directories:  [generic_inc, platform_inc],
  c_args:               tcl_args,
  # `$ORIGIN/../lib` so the installed tclsh in ${prefix}/bin can find
  # libtcl9.0.so in ${prefix}/lib without LD_LIBRARY_PATH or system
  # ldconfig wiring.  Set via -Wl,-rpath rather than meson's
  # install_rpath because the tclsh-zipfs custom_target copies this
  # binary at build time and the copy is what gets installed —
  # bypassing meson's install-time rpath patching.  Setting the rpath
  # at link time bakes it into the binary so the copy preserves it.
  link_args:            (is_win ? tclsh_link_args : []) + (is_win ? [] : ['-Wl,-rpath,$ORIGIN/../lib']),
  link_with:            [tcllib, tclstub],
  dependencies:         [zlib_dep, tommath_dep] + platform_deps,
  override_options:     override_opts,
)

# Append the zipfs archive to tclsh so it can find its init scripts
tclsh = custom_target('tclsh-zipfs',
  output:           tclsh_name + exe_suffix,
  input:            [tclsh_exe, tcl_zip],
  command:  [
    'sh', '-c',
    'cp "$1" "$3" && cat "$2" >> "$3" && chmod +x "$3"',
    'sh',
    '@INPUT0@',
    '@INPUT1@',
    '@OUTPUT@',
  ],
  build_by_default: true,
  install:          true,
  install_dir:      'bin',
  install_tag:      meson.is_subproject() ? 'deps' : 'runtime',
)

if host_machine.system() != 'windows'
  # Plain `tclsh` symlink so downstream consumers can rely on a
  # version-agnostic name on PATH.  Symlink is created at install
  # time (the meson.add_install_script below); the build-tree symlink
  # produced by this custom_target is consumed by `meson devenv`.
  custom_target(
    output:   'tclsh' + exe_suffix,
    command:  [find_program('ln', native: true), '-sf', tclsh_name + exe_suffix, '@OUTPUT@'],
    build_by_default: true,
  )
  meson.add_install_script(find_program('sh', native: true),
    '-c',
    'set -e; cd "$DESTDIR$MESON_INSTALL_PREFIX/bin" && ln -sf @0@@1@ tclsh@1@'.format(
      tclsh_name, exe_suffix),
    install_tag: meson.is_subproject() ? 'deps' : 'runtime',
  )
endif

tcl_library = meson.project_source_root() / 'library'
exec_prefix = meson.current_build_dir()

# Point TCL_LIBRARY at the source tree so tclsh can find init.tcl
meson.add_devenv({'TCL_LIBRARY': tcl_library})

# --- Public headers ---
# Downstream Tcl extensions need tcl.h + the public stubs decls + the
# tommath headers Tcl re-exposes for TclBN.  Match the canonical Tcl
# install set (the system tcl.pc's Cflags assume these are present).
public_headers = files(
  'generic/tcl.h',
  'generic/tclDecls.h',
  'generic/tclOO.h',
  'generic/tclOODecls.h',
  'generic/tclPlatDecls.h',
  'generic/tclTomMath.h',
  'generic/tclTomMathDecls.h',
)
install_data(public_headers,
  install_dir:  'include',
  install_tag:  'deps',
)

# --- pkg-config metadata ---
pc_conf = configuration_data()
pc_conf.set('PREFIX',  get_option('prefix'))
pc_conf.set('VERSION', meson.project_version())
configure_file(
  input:          'tcl.pc.in',
  output:         'tcl.pc',
  configuration:  pc_conf,
  install:        true,
  install_dir:    'lib' / 'pkgconfig',
  install_tag:    'deps',
)

# --- Dependency for consuming projects ---
#
# `libdir` here is the *install* libdir, used by consumer install_dir
# computations (`tcl_dep.get_variable('libdir') / 'pkgconfig'`, etc.)
# so .pc and per-package dirs land in the right place.  The build-time
# libtclstub for the wrap-fallback case is exposed via `link_with`
# below — consumers that need it use `tcl_dep.partial_dependency(links:
# true)`, not find_library against this libdir variable.
tcl_dep = declare_dependency(
  include_directories: generic_inc,
  link_with:           tclstub,
  # tclTomMath.h does `#include "tommath.h"` unless TCL_NO_TOMMATH_H is
  # defined, so any consumer that pulls in <tclTomMath.h> (e.g. for the
  # TclBN stubs in Tcl 9) needs libtommath's headers on the compile line.
  # Tcl itself is built with -DTCL_WITH_EXTERNAL_TOMMATH and links against
  # tommath_dep; we propagate the compile-only parts of that dep through
  # tcl_dep so downstream packages don't have to re-declare it themselves.
  dependencies:        [tommath_dep.partial_dependency(compile_args: true, includes: true)],
  version:             meson.project_version(),
  variables: {
    # Mirror the tcl.pc variables so consumers can use a uniform
    # tcl_dep.get_variable('NAME') call regardless of whether tcl came
    # from pkg-config or from this wrap.
    'prefix':      get_option('prefix'),
    'libdir':      get_option('prefix') / 'lib',
    'exec_prefix': get_option('prefix'),
    'source_root': meson.project_source_root(),
    'tcl_library': tcl_library,
  },
)
