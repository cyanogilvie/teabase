project('tcllib',
  version:            '2.0',
  meson_version:      '>=1.3.0',
)

tcllib_dep = declare_dependency(
  variables: {
    'tcl_pkg_path': meson.project_source_root() / 'modules',
    'version':      meson.project_version(),
  },
)
meson.override_dependency(meson.project_name(), tcllib_dep)

# vim: foldmethod=marker foldmarker=<<<,>>> shiftwidth=2 expandtab
