#ifndef TEABASE_REGISTER_CONFIG_H
#define TEABASE_REGISTER_CONFIG_H
#include <tcl.h>

void register_config(Tcl_Interp* interp, const char* pkgdir);
void deregiser_config(Tcl_Interp* interp);

#endif
