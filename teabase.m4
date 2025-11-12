builtin(include,teabase/ax_gcc_builtin.m4)
builtin(include,teabase/ax_cc_for_build.m4)
builtin(include,teabase/ax_check_compile_flag.m4)

AC_DEFUN([TEABASE_INIT], [
	# Test for -fprofile-partial-training, introduced in GCC 10
	AX_CHECK_COMPILE_FLAG([-fprofile-partial-training],
						[AC_SUBST(PGO_BUILD,"-fprofile-use=prof -fprofile-partial-training")],
						[AC_SUBST(PGO_BUILD,"-fprofile-use=prof")],
						[-Werror])
])

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

AC_DEFUN([REURI_STUBS], [
	if test "${STUBS_BUILD}" = "1"; then
		AC_DEFINE(USE_REURI_STUBS, 1, [Use ReURI Stubs])
	fi
])

#------------------------------------------------------------------------
# HIGHEST_C_STANDARD
#
#   Determines the highest C standard supported by the compiler.
#   Tests standards in descending order: C23, C17, C11, C99, C90.
#
# Arguments:
#   None
#
# Results:
#   Sets the following variables:
#     C_STD_CFLAGS - Compiler flags for the highest supported standard
#     C_STD_VERSION - The highest supported standard (e.g., "c23", "c17")
#------------------------------------------------------------------------
AC_DEFUN([HIGHEST_C_STANDARD], [
    AC_MSG_CHECKING([for highest supported C standard])

    # Save current CFLAGS
    SAVE_CFLAGS_STD="$CFLAGS"

    # Test standards in descending order
    for std in c23 c17 c11 c99 c90; do
        CFLAGS="$SAVE_CFLAGS_STD -std=$std"
        AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[]], [[]])],
            [C_STD_VERSION="$std"
             C_STD_CFLAGS="-std=$std"
             break],
            [])
    done

    # Restore CFLAGS
    CFLAGS="$SAVE_CFLAGS_STD"

    if test -n "$C_STD_VERSION"; then
        AC_MSG_RESULT([$C_STD_VERSION])
    else
        AC_MSG_RESULT([none, using compiler default])
        C_STD_CFLAGS=""
        C_STD_VERSION="default"
    fi

    AC_SUBST(C_STD_CFLAGS)
    AC_SUBST(C_STD_VERSION)
])

#------------------------------------------------------------------------
# CHECK_C23_EMBED
#
#   Checks if the compiler supports the C23 #embed directive.
#   Should be called after HIGHEST_C_STANDARD if you want to use
#   the detected standard for testing.
#
# Arguments:
#   None
#
# Results:
#   Defines HAVE_C23_EMBED if #embed is supported
#------------------------------------------------------------------------
AC_DEFUN([CHECK_C23_EMBED], [
    AC_MSG_CHECKING([if compiler supports @%:@embed directive])

    # Save current CFLAGS
    SAVE_CFLAGS_EMBED="$CFLAGS"

    # Use C_STD_CFLAGS if available, otherwise try with current flags
    if test -n "$C_STD_CFLAGS"; then
        CFLAGS="$SAVE_CFLAGS_EMBED $C_STD_CFLAGS"
    fi

    # Create a temporary test file to embed
    echo "test" > conftest_embed.txt

    AC_COMPILE_IFELSE([AC_LANG_SOURCE([[
        const char embedded_data@<:@@:>@ = {
        @%:@embed "conftest_embed.txt"
        , 0
        };
        int main(void) { return 0; }
    ]])],
    [AC_MSG_RESULT([yes])
     AC_DEFINE([HAVE_C23_EMBED], [1],
         [Define if compiler supports C23 @%:@embed directive])
     have_c23_embed=yes],
    [AC_MSG_RESULT([no])
     have_c23_embed=no])

    # Clean up
    rm -f conftest_embed.txt

    # Restore CFLAGS
    CFLAGS="$SAVE_CFLAGS_EMBED"
])
