#ifndef TEABASE_INSTANCE_TRACKING_H
#define TEABASE_INSTANCE_TRACKING_H
#include <tcl.h>

struct tracked_instance {
	// linked list accounting for all live Tcl values of our ObjType(s), to degrade to pure strings before we leave
	struct tracked_instance*	next;
	struct tracked_instance*	prev;
	Tcl_Obj*					self;	// No reference held (would create circular references)
};

struct tracked_instances {
	Tcl_Mutex				mtx;
	struct tracked_instance	head;
	struct tracked_instance	tail;
	Tcl_HashTable			hashtable;		// Alternateive mechanism for ObjTypes that have nowhere to put a struct tracked_instance
};

void register_instance(struct tracked_instances* instances, Tcl_Obj* obj, void* inst /* if NULL: use hash tracking */);
void forget_instance(struct tracked_instances* instances, Tcl_Obj* obj, void* inst /* if NULL: use hash tracking */);
void init_instance_tracking(struct tracked_instances* instances);
void finalize_instance_tracking(struct tracked_instances* instances);

#endif
