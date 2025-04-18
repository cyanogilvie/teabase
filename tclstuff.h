// Written by Cyan Ogilvie, and placed in the public domain

#ifndef _TCLSTUFF_H
#define _TCLSTUFF_H

#include <tcl.h>

#define NEW_CMD( tcl_cmd, c_cmd ) \
	Tcl_CreateObjCommand( interp, tcl_cmd, \
			(Tcl_ObjCmdProc *) c_cmd, \
			(ClientData *) NULL, NULL )

#define THROW_ERROR( ... )											\
	do {															\
		if (interp) Tcl_AppendResult(interp, ##__VA_ARGS__, NULL);	\
		return TCL_ERROR;											\
	} while(0)

#define THROW_PRINTF( fmtstr, ... )														\
	do {																				\
		if (interp) Tcl_SetObjResult(interp, Tcl_ObjPrintf((fmtstr), ##__VA_ARGS__));	\
		return TCL_ERROR;																\
	} while(0)

#define THROW_ERROR_LABEL( label, var, ... )							\
	do {																\
		if (interp) Tcl_AppendResult(interp, ##__VA_ARGS__, NULL);		\
		var = TCL_ERROR;												\
		goto label;														\
	} while(0)

#define THROW_PRINTF_LABEL( label, var, fmtstr, ... )									\
	do {																				\
		if (interp) Tcl_SetObjResult(interp, Tcl_ObjPrintf((fmtstr), ##__VA_ARGS__));	\
		var = TCL_ERROR;																\
		goto label;																		\
	} while(0)

#define THROW_POSIX_LABEL(label, code, msg)												\
	do {																				\
		int err = Tcl_GetErrno();														\
		const char* errstr = Tcl_ErrnoId();												\
		if (interp) Tcl_SetErrorCode(interp, "POSIX", errstr, Tcl_ErrnoMsg(err), NULL);	\
		THROW_PRINTF_LABEL(label, code, "%s: %s %s", msg, errstr, Tcl_ErrnoMsg(err));	\
	} while(0)

// convenience macro to check the number of arguments passed to a function
// implementing a tcl command against the number expected, and to throw
// a tcl error if they don't match.  Note that the value of expected does
// not include the objv[0] object (the function itself)
#define CHECK_ARGS(expected, msg)										\
	if (objc != expected + 1) {											\
		if (interp) Tcl_WrongNumArgs(interp, 1, objv, sizeof(msg) > 1 ? msg : NULL);\
		return TCL_ERROR;												\
	}

#define CHECK_ARGS_LABEL2(label, rc) \
	do { \
		if (objc != A_objc) { \
			if (interp) Tcl_WrongNumArgs(interp, A_cmd+1, objv, NULL); \
			rc = TCL_ERROR; \
			goto label; \
		} \
	} while(0)
#define CHECK_ARGS_LABEL3(label, rc, msg) \
	do { \
		if (objc != A_objc) { \
			if (interp) Tcl_WrongNumArgs(interp, A_cmd+1, objv, sizeof(msg) > 1 ? msg : NULL); \
			rc = TCL_ERROR; \
			goto label; \
		} \
	} while(0)
#define GET_CHECK_ARGS_LABEL_MACRO(_1,_2,_3,NAME,...) NAME
#define CHECK_ARGS_LABEL(...) GET_CHECK_ARGS_LABEL_MACRO(__VA_ARGS__, CHECK_ARGS_LABEL3, CHECK_ARGS_LABEL2)(__VA_ARGS__)

#define CHECK_MIN_ARGS_LABEL(label, rc, msg) \
	do { \
		if (objc < A_args) { \
			if (interp) Tcl_WrongNumArgs(interp, A_cmd+1, objv, sizeof(msg) > 1 ? msg : NULL); \
			rc = TCL_ERROR; \
			goto label; \
		} \
	} while(0)

#define CHECK_RANGE_ARGS_LABEL(label, rc, msg) \
	do { \
		if (objc < A_args || objc > A_objc) { \
			if (interp) Tcl_WrongNumArgs(interp, A_cmd+1, objv, sizeof(msg) > 1 ? msg : NULL); \
			rc = TCL_ERROR; \
			goto label; \
		} \
	} while(0)


// A rather frivolous macro that just enhances readability for a common case
#define TEST_OK( cmd )		\
	if (cmd != TCL_OK) return TCL_ERROR

#define TEST_OK_LABEL( label, var, cmd )		\
	if (cmd != TCL_OK) { \
		var = TCL_ERROR; \
		goto label; \
	}

#define TEST_OK_BREAK(var, cmd) if (TCL_OK != (var=(cmd))) break

static inline void release_tclobj(Tcl_Obj** obj)
{
	if (*obj) {
		Tcl_DecrRefCount(*obj);
		*obj = NULL;
	}
}
#define RELEASE_MACRO(obj)		if (obj) {Tcl_DecrRefCount(obj); obj=NULL;}
#define REPLACE_MACRO(target, replacement)	\
do { \
	release_tclobj(&target); \
	if (replacement) Tcl_IncrRefCount(target = replacement); \
} while(0)
static inline void replace_tclobj(Tcl_Obj** target, Tcl_Obj* replacement)
{
	Tcl_Obj*	old = *target;

#if DEBUG
	if (*target && (*target)->refCount <= 0) Tcl_Panic("replace_tclobj target exists but has refcount <= 0: %d", (*target)->refCount);
#endif
	*target = replacement;
	if (*target) Tcl_IncrRefCount(*target);
	if (old) {
		Tcl_DecrRefCount(old);
		old = NULL;
	}
}

#if DEBUG
#	 include <signal.h>
#	 include <unistd.h>
#	 include <time.h>
#	 include "names.h"
#	 define DBG(...) fprintf(stdout, ##__VA_ARGS__)
#	 define FDBG(...) fprintf(stdout, ##__VA_ARGS__)
#	 define DEBUGGER raise(SIGTRAP)
#	 define TIME(label, task) \
	do { \
		struct timespec first; \
		struct timespec second; \
		struct timespec after; \
		double empty; \
		double delta; \
		clock_gettime(CLOCK_MONOTONIC, &first); /* Warm up the call */ \
		clock_gettime(CLOCK_MONOTONIC, &first); \
		clock_gettime(CLOCK_MONOTONIC, &second); \
		task; \
		clock_gettime(CLOCK_MONOTONIC, &after); \
		empty = second.tv_sec - first.tv_sec + (second.tv_nsec - first.tv_nsec)/1e9; \
		delta = after.tv_sec - second.tv_sec + (after.tv_nsec - second.tv_nsec)/1e9 - empty; \
		DBG("Time for %s: %.1f microseconds\n", label, delta * 1e6); \
	} while(0)
#else
#	define DBG(...) /* nop */
#	define FDBG(...) /* nop */
#	define DEBUGGER /* nop */
#	define TIME(label, task) task
#endif

#define OBJCMD(name)	int (name)(ClientData cdata, Tcl_Interp* interp, int objc, Tcl_Obj *const objv[])
#define INIT			int init(Tcl_Interp* interp)
#define RELEASE			void release(Tcl_Interp* interp)

#endif
