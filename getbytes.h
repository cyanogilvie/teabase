#ifndef _GETBYTES_H
#define _GETBYTES_H

#if GETBYTES_SHIM

#include <stdint.h>

/*
 * Polyfill for Tcl_GetBytesFromObj, added in Tcl 8.7/9.0.
 * Adapts the older Tcl_GetByteArrayFromObj(obj, int*) to the newer
 * Tcl_GetBytesFromObj(interp, obj, Tcl_Size*) signature.
 */

static inline uint8_t* Tcl_GetBytesFromObj(Tcl_Interp* interp, Tcl_Obj* obj, Tcl_Size* lenPtr)
{
	Tcl_Size	len;
	uint8_t*	bytes;
	(void)interp;
	bytes = Tcl_GetByteArrayFromObj(obj, &len);
	*lenPtr = len;
	return bytes;
}

#endif	/* GETBYTES_SHIM */

#endif	/* _GETBYTES_H */
