#!/usr/bin/env python3
"""
Build version-pinned interned static dependencies from a JSON manifest.

Designed to be called from meson custom_targets (or autotools Makefile rules)
as a single unified entry point for building C library dependencies that get
statically linked into a Tcl extension.

The driving goal is reproducibility: a given git rev of the parent package
should strictly imply the exact source and build parameters for its
dependencies, independent of the developer's shell environment.  This script
enforces that by:

  * sanitizing the environment (dropping CFLAGS / CXXFLAGS / LDFLAGS /
    CPPFLAGS / MAKEFLAGS before invoking cmake / configure / make);
  * always wiping any stale cmake build dir before re-configuring, which
    defends against cached flags from a previous run that had environment
    variables set;
  * pinning CMAKE_C_FLAGS / CMAKE_CXX_FLAGS to the manifest values (empty
    by default) so env CFLAGS can't leak into cmake's cache;
  * hashing the manifest + submodule SHAs + host triple into a stamp file
    and short-circuiting when nothing relevant has changed.

Manifest schema (JSON):

  {
    "deps": {
      "<name>": {
        "source":  "<path relative to --source-root>",
        "builder": "cmake" | "autoconf" | "make",
        "depends": ["<other dep name>", ...],       # optional
        "defines": { "CMAKE_VAR": "value", ... },   # cmake only
        "configure_flags": ["--with-foo", ...],     # autoconf only
        "make_env":        { "FOO": "bar", ... },   # make only
        "makefile":        "makefile.shared",       # make only, default "makefile"
        "post_install": [                           # optional, any builder
          {
            "type": "sed",
            "file": "${prefix}/lib/foo.cmake",
            "replace": [["search", "replace"], ...]
          }
        ]
      }
    },
    "unsupported_hosts": ["*-*-mingw*", ...]   # optional fnmatch patterns
  }

String values in 'defines', 'configure_flags', 'make_env', and
'post_install' may reference ${prefix}, ${host}, or ${source} (the resolved
source directory of the current dep) and these will be expanded at runtime.
"""

import argparse
import fnmatch
import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path


# Environment variables that would leak build configuration into the
# interned dep build if propagated.  These are dropped from the env before
# every subprocess invocation.  If a dep's build genuinely needs one of
# these (rare), the manifest should pass it explicitly as a cmake define or
# configure flag.
ENV_BLOCK = frozenset({
    'CFLAGS', 'CXXFLAGS', 'CPPFLAGS', 'LDFLAGS',
    'CMAKE_C_FLAGS', 'CMAKE_CXX_FLAGS',
    'MAKEFLAGS', 'MAKELEVEL',
})


def sanitized_env():
    return {k: v for k, v in os.environ.items() if k not in ENV_BLOCK}


def detect_host():
    """Return a gcc-style triplet for the current build host."""
    for cc in ('cc', 'gcc', 'clang'):
        try:
            r = subprocess.run([cc, '-dumpmachine'],
                               capture_output=True, text=True, check=True)
            return r.stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError):
            continue
    # No C compiler found in PATH — fall back to a coarse uname-based triple.
    m = platform.machine()
    s = platform.system().lower()
    if s == 'linux':
        return f'{m}-pc-linux-gnu'
    if s == 'darwin':
        return f'{m}-apple-darwin'
    if s == 'windows':
        return f'{m}-pc-mingw64'
    return f'{m}-unknown-{s}'


def host_matches(host, patterns):
    return any(fnmatch.fnmatch(host, p) for p in patterns)


def git_sha(source_dir):
    """Return HEAD SHA of source_dir as a git tree, or a deep content hash."""
    try:
        r = subprocess.run(
            ['git', '-C', str(source_dir), 'rev-parse', 'HEAD'],
            capture_output=True, text=True, check=True)
        sha = r.stdout.strip()
        # Also fold in whether the working tree is dirty, so a dev who
        # hacks on the dep source without committing still gets rebuilds.
        dirty = subprocess.run(
            ['git', '-C', str(source_dir), 'status', '--porcelain'],
            capture_output=True, text=True, check=False).stdout
        if dirty.strip():
            sha += '-dirty-' + hashlib.sha256(dirty.encode()).hexdigest()[:8]
        return sha
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    # Fall back: hash the tree contents.  Slow on large trees but correct.
    h = hashlib.sha256()
    for p in sorted(Path(source_dir).rglob('*')):
        if p.is_file():
            h.update(str(p.relative_to(source_dir)).encode())
            h.update(p.read_bytes())
    return h.hexdigest()


_INTERP_RE = re.compile(r'\$\{([^}]+)\}')


def interpolate(value, vars):
    """Recursively expand ${name} references in strings inside value."""
    if isinstance(value, str):
        return _INTERP_RE.sub(lambda m: vars.get(m.group(1), m.group(0)), value)
    if isinstance(value, list):
        return [interpolate(v, vars) for v in value]
    if isinstance(value, dict):
        return {k: interpolate(v, vars) for k, v in value.items()}
    return value


def topo_sort(deps):
    """Return dep names in build order, respecting 'depends' edges."""
    order = []
    seen = set()

    def visit(name, path):
        if name in seen:
            return
        if name in path:
            raise ValueError(f'dependency cycle: {" -> ".join(path + [name])}')
        for d in deps[name].get('depends', []):
            if d not in deps:
                raise ValueError(
                    f'{name}: depends on unknown {d!r}')
            visit(d, path + [name])
        seen.add(name)
        order.append(name)

    for name in deps:
        visit(name, [])
    return order


class Builder:
    def __init__(self, name, spec, source_dir, build_dir, prefix, vars, jobs):
        self.name = name
        self.spec = spec
        self.source_dir = source_dir
        self.build_dir = build_dir
        self.prefix = prefix
        self.vars = vars
        self.jobs = jobs

    def _log(self, msg):
        print(f'[interned_deps:{self.name}] {msg}', flush=True)

    def _run(self, cmd, cwd=None):
        self._log(' '.join(str(c) for c in cmd))
        subprocess.run(cmd, check=True, env=sanitized_env(), cwd=cwd)

    def build(self):
        raise NotImplementedError


class CmakeBuilder(Builder):
    def build(self):
        # Always wipe the build dir before re-configuring.  cmake caches
        # CMAKE_C_FLAGS on first run and never re-evaluates environment on
        # subsequent runs, so a stale cache from a previous run with env
        # CFLAGS set (e.g. -fsanitize=address) would silently contaminate
        # every future build.
        if self.build_dir.exists():
            shutil.rmtree(self.build_dir)
        self.build_dir.mkdir(parents=True)

        defines = interpolate(self.spec.get('defines', {}), self.vars)
        # Pin CMAKE_C_FLAGS / CMAKE_CXX_FLAGS to the manifest values (empty
        # by default).  This overrides whatever cmake would otherwise
        # inherit from the environment on first configure.
        defines.setdefault('CMAKE_C_FLAGS', '')
        defines.setdefault('CMAKE_CXX_FLAGS', '')
        # Ensure a sensible install prefix is set unless the manifest
        # supplied one.
        defines.setdefault('CMAKE_INSTALL_PREFIX', str(self.prefix))

        cmd = ['cmake', '-B', str(self.build_dir), '-S', str(self.source_dir)]
        for k, v in defines.items():
            cmd.append(f'-D{k}={v}')
        self._run(cmd)

        self._run(['cmake', '--build', str(self.build_dir),
                   '-j', str(self.jobs)])
        self._run(['cmake', '--install', str(self.build_dir)])


class AutoconfBuilder(Builder):
    def build(self):
        if self.build_dir.exists():
            shutil.rmtree(self.build_dir)
        self.build_dir.mkdir(parents=True)

        configure = self.source_dir / 'configure'
        if not configure.exists():
            raise FileNotFoundError(
                f'{self.name}: {configure} not found (run autoreconf?)')

        args = [str(configure), f'--prefix={self.prefix}']
        args.extend(interpolate(self.spec.get('configure_flags', []), self.vars))
        self._run(args, cwd=self.build_dir)
        self._run(['make', f'-j{self.jobs}'], cwd=self.build_dir)
        self._run(['make', 'install'], cwd=self.build_dir)


class MakeBuilder(Builder):
    def build(self):
        # 'make' builds happen in-tree (the source dir IS the build dir),
        # so a stale object from a previous run could otherwise corrupt
        # the build.  Default to running `make clean` first; the manifest
        # can override with pre_build to a different list of targets, or
        # disable with an empty list.
        #
        # If the manifest doesn't specify a makefile, omit -f and let make
        # use its standard search order (GNUmakefile, makefile, Makefile).
        make_base = ['make']
        makefile = self.spec.get('makefile')
        if makefile:
            make_base += ['-f', makefile]
        make_env = interpolate(self.spec.get('make_env', {}), self.vars)
        common = [f'{k}={v}' for k, v in make_env.items()]
        common.append(f'PREFIX={self.prefix}')
        for target in self.spec.get('pre_build', ['clean']):
            self._run(make_base + common + [target], cwd=self.source_dir)
        self._run(make_base + [f'-j{self.jobs}'] + common,
                  cwd=self.source_dir)
        self._run(make_base + ['install'] + common, cwd=self.source_dir)


BUILDERS = {
    'cmake':    CmakeBuilder,
    'autoconf': AutoconfBuilder,
    'make':     MakeBuilder,
}


def sed_hook(hook, vars):
    file = Path(interpolate(hook['file'], vars))
    content = file.read_text()
    for pattern, replacement in hook['replace']:
        content = content.replace(
            interpolate(pattern, vars),
            interpolate(replacement, vars))
    file.write_text(content)


HOOKS = {
    'sed': sed_hook,
}


def compute_stamp_hash(manifest_path, deps, host):
    h = hashlib.sha256()
    h.update(manifest_path.read_bytes())
    h.update(b'\n__host__\n')
    h.update(host.encode())
    for name in sorted(deps):
        spec = deps[name]
        sha = git_sha(spec['source'])
        h.update(f'\n{name}:{sha}'.encode())
    return h.hexdigest()


def read_stamp(stamp_path):
    if not stamp_path.exists():
        return None
    try:
        return json.loads(stamp_path.read_text())
    except (json.JSONDecodeError, OSError):
        return None


def write_stamp(stamp_path, stamp_hash, prefix):
    stamp_path.parent.mkdir(parents=True, exist_ok=True)
    stamp_path.write_text(json.dumps({
        'hash':   stamp_hash,
        'prefix': str(prefix),
    }, indent=2) + '\n')


def main():
    ap = argparse.ArgumentParser(description=__doc__.strip().split('\n\n')[0])
    ap.add_argument('--manifest', required=True, type=Path,
                    help='Path to the JSON manifest')
    ap.add_argument('--source-root', type=Path, default=Path.cwd(),
                    help='Root directory that dep "source" paths are relative to')
    ap.add_argument('--prefix', required=True, type=Path,
                    help='Shared install prefix for all deps')
    ap.add_argument('--build', required=True, type=Path,
                    help='Root directory for per-dep build trees')
    ap.add_argument('--stamp', required=True, type=Path,
                    help='Stamp file written on success')
    ap.add_argument('--jobs', type=int, default=os.cpu_count() or 1,
                    help='Parallel build jobs (default: nproc)')
    ap.add_argument('--host', default=None,
                    help='Target host triple (default: detect)')
    ap.add_argument('--force', action='store_true',
                    help='Rebuild even if the stamp is up-to-date')
    ap.add_argument('--copy-artifact', action='append', default=[],
                    metavar='SRC:DEST',
                    help='After a successful build, copy <prefix>/<SRC> to '
                         '<DEST>.  Used to flatten cmake\'s lib/ install layout '
                         'into a meson custom_target output namespace.  May be '
                         'repeated.')
    args = ap.parse_args()

    try:
        manifest = json.loads(args.manifest.read_text())
    except (json.JSONDecodeError, OSError) as e:
        print(f'ERROR: cannot read manifest {args.manifest}: {e}',
              file=sys.stderr)
        return 1

    deps = manifest.get('deps', {})
    if not deps:
        print(f'ERROR: manifest {args.manifest} has no deps', file=sys.stderr)
        return 1

    host = args.host or detect_host()
    unsupported = manifest.get('unsupported_hosts', [])
    if host_matches(host, unsupported):
        print(f'ERROR: host {host!r} is declared unsupported in '
              f'{args.manifest} (matched pattern in unsupported_hosts)',
              file=sys.stderr)
        return 1

    # Resolve source paths against --source-root.
    source_root = args.source_root.resolve()
    for name, spec in deps.items():
        spec['source'] = (source_root / spec['source']).resolve()
        if not spec['source'].is_dir():
            print(f'ERROR: {name}: source {spec["source"]} not found',
                  file=sys.stderr)
            return 1

    # Validate --copy-artifact specs up front so a bad arg fails fast.
    copy_specs = []
    for spec in args.copy_artifact:
        if ':' not in spec:
            print(f'ERROR: --copy-artifact must be SRC:DEST, got {spec!r}',
                  file=sys.stderr)
            return 1
        src_rel, dest = spec.split(':', 1)
        copy_specs.append((src_rel, Path(dest)))

    def do_copy_artifacts(prefix):
        for src_rel, dest_path in copy_specs:
            src = prefix / src_rel
            if not src.is_file():
                print(f'ERROR: --copy-artifact source {src} not found',
                      file=sys.stderr)
                return False
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dest_path)
            print(f'[interned_deps] copied {src} -> {dest_path}', flush=True)
        return True

    prefix = args.prefix.resolve()
    stamp_hash = compute_stamp_hash(args.manifest, deps, host)

    # Stamp is valid only if hash matches AND prefix exists AND every
    # --copy-artifact destination still exists.  This handles the case
    # where the meson custom_target outputs were wiped (deps-clean) but
    # the install prefix was somehow left intact.
    def all_copy_dests_present():
        return all(dest.is_file() for _, dest in copy_specs)

    prior = read_stamp(args.stamp)
    if (not args.force
            and prior
            and prior.get('hash') == stamp_hash
            and prior.get('prefix') == str(prefix)
            and prefix.exists()
            and all_copy_dests_present()):
        print(f'[interned_deps] stamp up-to-date for {host}, skipping',
              flush=True)
        return 0

    order = topo_sort(deps)
    print(f'[interned_deps] host={host} order={order}', flush=True)

    build_root = args.build.resolve()
    build_root.mkdir(parents=True, exist_ok=True)
    prefix.mkdir(parents=True, exist_ok=True)

    vars = {
        'prefix': str(prefix),
        'host':   host,
        'jobs':   str(args.jobs),
    }

    for name in order:
        spec = deps[name]
        vars['source'] = str(spec['source'])
        builder_cls = BUILDERS.get(spec.get('builder'))
        if not builder_cls:
            print(f'ERROR: {name}: unknown builder '
                  f'{spec.get("builder")!r}', file=sys.stderr)
            return 1
        build_dir = build_root / name
        b = builder_cls(name, spec, spec['source'], build_dir, prefix,
                        dict(vars), args.jobs)
        try:
            b.build()
        except subprocess.CalledProcessError as e:
            print(f'ERROR: {name}: build failed ({e})', file=sys.stderr)
            return 1
        for hook in spec.get('post_install', []):
            hook_fn = HOOKS.get(hook.get('type'))
            if not hook_fn:
                print(f'ERROR: {name}: unknown post_install type '
                      f'{hook.get("type")!r}', file=sys.stderr)
                return 1
            try:
                hook_fn(hook, vars)
            except OSError as e:
                print(f'ERROR: {name}: post_install {hook["type"]} failed: {e}',
                      file=sys.stderr)
                return 1

    if not do_copy_artifacts(prefix):
        return 1

    write_stamp(args.stamp, stamp_hash, prefix)
    print(f'[interned_deps] build complete, stamp written to {args.stamp}',
          flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
