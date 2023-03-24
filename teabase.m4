builtin(include,ax_gcc_builtin.m4)
builtin(include,ax_cc_for_build.m4)
builtin(include,ax_check_compile_flag.m4)

AC_DEFUN([ENABLE_DEBUG], [
	#trap 'echo "val: (${enable_debug+set}), debug_ok: ($debug_ok), DEBUG: ($DEBUG)"' DEBUG
	AC_MSG_CHECKING([whether to support debuging])
	AC_ARG_ENABLE(debug,
		AS_HELP_STRING([--enable-debug],[Enable debug mode (not symbols, but portions of the code that are only used in debug builds) (default: no)]),
		[debug_ok=$enableval], [debug_ok=no])

	if test "$debug_ok" = "yes" -o "${DEBUG}" = 1; then
		DEBUG=1
		AC_MSG_RESULT([yes])
	else
		DEBUG=0
		AC_MSG_RESULT([no])
	fi

	AC_DEFINE_UNQUOTED([DEBUG], [$DEBUG], [Debug enabled?])
	#trap '' DEBUG
])

AC_DEFUN([ENABLE_UNLOAD], [
	#trap 'echo "val: (${enable_unload+set}), unload_ok: ($unload_ok), UNLOAD: ($UNLOAD)"' DEBUG
	AC_MSG_CHECKING([whether to support unloading])
	AC_ARG_ENABLE(unload,
		AS_HELP_STRING([--enable-unload],[Add support for unloading this shared library (default: no)]),
		[unload_ok=$enableval], [unload_ok=no])

	if test "$unload_ok" = "yes" -o "${UNLOAD}" = 1; then
		UNLOAD=1
		AC_MSG_RESULT([yes])
	else
		UNLOAD=0
		AC_MSG_RESULT([no])
	fi

	AC_DEFINE_UNQUOTED([UNLOAD], [$UNLOAD], [Unload enabled?])
	#trap '' DEBUG
])

AC_DEFUN([ENABLE_TESTMODE], [
	#trap 'echo "val: (${enable_testmode+set}), testmode_ok: ($testmode_ok), TESTMODE: ($TESTMODE)"' DEBUG
	AC_MSG_CHECKING([whether to build in test mode])
	AC_ARG_ENABLE(testmode,
		AS_HELP_STRING([--enable-testmode],[Build with whitebox testing hooks exposed (default: no)]),
		[testmode_ok=$enableval], [testmode_ok=no])

	if test "$testmode_ok" = "yes" -o "${TESTMODE}" = 1; then
		TESTMODE=1
		AC_MSG_RESULT([yes])
	else
		TESTMODE=0
		AC_MSG_RESULT([no])
	fi

	AC_DEFINE_UNQUOTED([TESTMODE], [$TESTMODE], [Test mode enabled?])
	#trap '' DEBUG
])

AC_DEFUN([CHECK_TESTMODE], [
	AC_MSG_CHECKING([whether to build in test mode])
	AC_ARG_ENABLE(testmode,
		[  --enable-testmode       Build in test mode (default: off)],
		[enable_testmode=$enableval],
		[enable_testmode="no"])
	AC_MSG_RESULT($enable_testmode)
	if test "$enable_testmode" = "yes"
	then
		AC_DEFINE(TESTMODE)
	fi
])

AC_DEFUN([TIP445], [
	AC_MSG_CHECKING([whether we need to polyfill TIP 445])
	saved_CFLAGS="$CFLAGS"
	CFLAGS="$CFLAGS $TCL_INCLUDE_SPEC"
	AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[#include <tcl.h>]], [[Tcl_ObjInternalRep ir;]])],[have_tcl_objintrep=yes],[have_tcl_objintrep=no])
	CFLAGS="$saved_CFLAGS"

	if test "$have_tcl_objintrep" = yes; then
		AC_DEFINE(TIP445_SHIM, 0, [Do we need to polyfill TIP 445?])
		AC_MSG_RESULT([no])
	else
		AC_DEFINE(TIP445_SHIM, 1, [Do we need to polyfill TIP 445?])
		AC_MSG_RESULT([yes])
	fi
])

# All the best stuff seems to be Linux / glibc specific :(
AC_DEFUN([CHECK_GLIBC], [
	AC_MSG_CHECKING([for GNU libc])
	AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[#include <features.h>]], [[
#if ! (defined __GLIBC__ || defined __GNU_LIBRARY__)
#	error "Not glibc"
#endif
]])],[glibc=yes],[glibc=no])

	if test "$glibc" = yes
	then
		AC_DEFINE(_GNU_SOURCE, 1, [Always define _GNU_SOURCE when using glibc])
		AC_MSG_RESULT([yes])
	else
		AC_MSG_RESULT([no])
	fi
])


# We need a modified version of TEA_ADD_SOURCES because some of those files will be
# generated *after* the macro runs, so it can't test for existence:
AC_DEFUN([TEABASE_ADD_SOURCES], [
    vars="$@"
    for i in $vars; do
	case $i in
	    [\$]*)
		# allow $-var names
		PKG_SOURCES="$PKG_SOURCES $i"
		PKG_OBJECTS="$PKG_OBJECTS $i"
		;;
	    *)
		PKG_SOURCES="$PKG_SOURCES $i"
		# this assumes it is in a VPATH dir
		i=`basename $i`
		# handle user calling this before or after TEA_SETUP_COMPILER
		if test x"${OBJEXT}" != x ; then
		    j="`echo $i | sed -e 's/\.[[^.]]*$//'`.${OBJEXT}"
		else
		    j="`echo $i | sed -e 's/\.[[^.]]*$//'`.\${OBJEXT}"
		fi
		PKG_OBJECTS="$PKG_OBJECTS $j"
		;;
	esac
    done
    AC_SUBST(PKG_SOURCES)
    AC_SUBST(PKG_OBJECTS)
])

AC_DEFUN([DEDUP_STUBS], [
	if test "${STUBS_BUILD}" = "1"; then
		AC_DEFINE(USE_DEDUP_STUBS, 1, [Use Dedup Stubs])
	fi
])

