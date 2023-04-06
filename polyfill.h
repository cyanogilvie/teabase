#ifndef POLYFILL
#define POLYFILL

#ifndef Tcl_DStringToObj
static Tcl_Obj* Tcl_DStringToObj(Tcl_DString* ds)
{
	Tcl_Obj*	res = NULL;

	if (ds->string == ds->staticSpace) {
		return ds->length ? Tcl_NewStringObj(ds->string, ds->length) : Tcl_NewObj();
	} else {
		res = Tcl_NewObj();
		res->bytes  = ds->string;
		res->length = ds->length;
	}

	ds->string = ds->staticSpace;
	ds->spaceAvl = TCL_DSTRING_STATIC_SIZE;
	ds->length = 0;
	ds->staticSpace[0] = 0;

	return res;
}
#endif

#endif
