if not is_variable('teabase_initialized')
  subdir('init')
endif

pkg_so = shared_module(meson.project_name(),
  pkg_sources,
  install:      true,
  install_dir:  pkg_dir,
  dependencies: deps,
  include_directories: inc,
)

teaconf.set('PKG_LIB_FILE', fs.name(pkg_so.full_path()))

configure_file(input: '../pkgIndex.tcl.in', output: '@BASENAME@',
  configuration:  teaconf,
  install_dir:    pkg_dir,
  install_tag:    'runtime',
)

# Arrange for our the package path to be first in $::auto_path
meson.add_devenv(environment({
  'TCLLIBPATH': meson.current_build_dir(),
}))

if tclsh.found()
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
    env: {
      'ERROR_ON_FAILURES': '1',
    },
  )

  vim = find_program('vim', version: '>=8.1', native: true, required: false)
  if not vim.found()
    vim = find_program('nvim', version: '>=0.4', native: true, required: false)
  endif

  if vim.found()
    termdebug_arg = run_command(tclsh, meson.current_source_dir() / 'tools/make_termdebug_arg.tcl',
      meson.project_build_root(),
      tclsh.full_path(),
      meson.project_name(),
      meson.project_version(),
      check: true,
    ).stdout().strip()

    message('Found Vim/Neovim: ' + vim.full_path() + ' for vim-gdb target')
    run_target('vim-gdb',
      command:  [vim,
        '-c', 'set number',
        '-c', 'set mouse=a',
        '-c', 'set foldlevel=100',
        '-c', 'packadd termdebug',
        '-c', termdebug_arg,
        '-c', '2windo set nonumber',
        '-c', '1windo set nonumber',
      ],
    )
  endif
endif

configure_file(output: 'config.h', configuration: conf)
inc += include_directories('.')
