#include <config.h>
#include <tcl.h>

void register_config(Tcl_Interp* interp, const char* pkgdir)
{
	/* Despite what the Tcl_RegisterConfig manpage claims, these values *ARE*
	 * copied, so using `pkgdir` here is fine. (8.6 and 9.0)
	 */
	Tcl_RegisterConfig(interp, PACKAGE_NAME, (Tcl_Config[]){
		{"libdir,runtime",		pkgdir},
		{"includedir,runtime",	pkgdir},
		{"packagedir,runtime",	pkgdir},
		{"library",				PACKAGE_LIBNAME},
		{"stublib",				PACKAGE_STUBLIB},
		{"header",				PACKAGE_NAME ".h"},
		{0}
	}, "utf-8");
}

void deregiser_config(Tcl_Interp* interp)
{
	Tcl_DeleteCommand(interp, "::" PACKAGE_NAME "::pkgconfig");
}
