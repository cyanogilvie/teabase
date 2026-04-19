#ifndef _GETBYTES_H
#define _GETBYTES_H

#if GETBYTES_SHIM

#include <stdint.h>
#include <string.h>

/*
 * Polyfill for Tcl_GetBytesFromObj, added in Tcl 8.7/9.0.  Returns the
 * byte-array interpretation of obj, or NULL (with a TCL VALUE BYTES
 * errorCode and readable error message) if the string representation
 * contains any characters outside the 0..255 range.
 *
 * This matches Tcl 9's Tcl_GetBytesFromObj semantics.  Older
 * Tcl_GetByteArrayFromObj accepted any string, silently truncating
 * Unicode characters to their low 8 bits — which is usually wrong when
 * the caller wanted "bytes or error".
 */

static inline uint8_t* Tcl_GetBytesFromObj(Tcl_Interp* interp, Tcl_Obj* obj, Tcl_Size* lenPtr)
{
	Tcl_Size	bytelen;
	uint8_t*	bytes;

	/* Already a bytearray internal rep — no validation needed. */
	if (obj->typePtr != NULL && strcmp(obj->typePtr->name, "bytearray") == 0) {
		bytes = Tcl_GetByteArrayFromObj(obj, &bytelen);
		if (lenPtr) *lenPtr = bytelen;
		return bytes;
	}

	/*
	 * Validate the string rep is pure-byte before shimmering to bytearray.
	 * The error message matches Tcl 9's Tcl_GetBytesFromObj: the index
	 * is the number of valid bytes seen so far (one per ch<=0xFF), and
	 * the bad-character field is the tail of the string starting at the
	 * offending character.
	 */
	int		strlen_int;
	const char*	str = Tcl_GetStringFromObj(obj, &strlen_int);
	int		good = 0;
	for (int i=0; i < strlen_int; ) {
		Tcl_UniChar	ch;
		int		chlen = Tcl_UtfToUniChar(str + i, &ch);
		if (ch > 0xFF) {
			if (interp) {
				Tcl_SetObjResult(interp, Tcl_ObjPrintf(
					"expected byte sequence but character %d was '%s' (U+%06X)",
					good, str + i, (int)ch));
				Tcl_SetErrorCode(interp, "TCL", "VALUE", "BYTES", NULL);
			}
			return NULL;
		}
		i += chlen;
		good++;
	}

	bytes = Tcl_GetByteArrayFromObj(obj, &bytelen);
	if (lenPtr) *lenPtr = bytelen;
	return bytes;
}

#endif	/* GETBYTES_SHIM */

#endif	/* _GETBYTES_H */
