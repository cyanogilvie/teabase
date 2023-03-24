VALGRINDEXTRA =
VALGRINDARGS	= --tool=memcheck --num-callers=8 --leak-resolution=high \
		  --leak-check=yes -v --suppressions=suppressions --keep-debuginfo=yes \
		  --trace-children=yes $(VALGRINDEXTRA)

PGOGEN_BUILD = -fprofile-generate=prof
PGO_BUILD = @PGO_BUILD@
PGO=

CFLAGS		= @CFLAGS@ $(PGO)

benchmark: binaries libraries
	$(TCLSH) `@CYGPATH@ $(srcdir)/bench/run.tcl` $(TESTFLAGS) -load package\ ifneeded\ $(PACKAGE_NAME)\ $(PACKAGE_VERSION)\ [list\ load\ `@CYGPATH@ $(PKG_LIB_FILE)`\ [string\ totitle\ $(PACKAGE_NAME)]]

tags: generic/*
	ctags-exuberant generic/*

vim-core:
	$(TCLSH_ENV) $(PKG_ENV) vim -c 'packadd termdebug' -c "set mouse=a" -c "set number" -c "set foldlevel=100" -c "Termdebug $(TCLSH_PROG) core" -c Winbar generic/

vim-gdb: binaries libraries
	$(TCLSH_ENV) $(PKG_ENV) vim -c "set number" -c "set mouse=a" -c "set foldlevel=100" -c "Termdebug -ex set\ print\ pretty\ on --args $(TCLSH_PROG) tests/all.tcl $(TESTFLAGS) -singleproc 1 -load package\ ifneeded\ $(PACKAGE_NAME)\ $(PACKAGE_VERSION)\ [list\ load\ `@CYGPATH@ $(PKG_LIB_FILE)`\ [string\ totitle\ $(PACKAGE_NAME)]]" -c "2windo set nonumber" -c "1windo set nonumber" generic/

pgo:
	rm -rf prof
	make -C . PGO="$(PGOGEN_BUILD)" clean binaries libraries benchmark
	make -C . PGO="$(PGO_BUILD)" clean binaries libraries

coverage:
	make -C . PGO="--coverage" clean binaries libraries test

test-container:
	docker run --rm -it --platform $(PLATFORM) -v "$(realpath $(srcdir)):/src/resolvelocal:ro" cyanogilvie/alpine-tcl:v0.9.66-gdb /src/resolvelocal/dtest.tcl "$(TESTFLAGS)"

build-container:
	mkdir -p "$(top_builddir)/dockerbuild"
	docker run --rm -it --platform $(PLATFORM) -v "$(realpath $(srcdir)):/src/resolvelocal:ro" -v "$(top_builddir)/dockerbuild:/install" cyanogilvie/alpine-tcl:v0.9.66-gdb /src/resolvelocal/dbuild.tcl "$(shell id -u)" "$(shell id -g)"
.PHONY: vim-gdb vim-core pgo coverage benchmark
