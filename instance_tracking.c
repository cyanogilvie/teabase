#include <instance_tracking.h>

void register_instance(struct tracked_instances* instances, Tcl_Obj* obj, void* inst /* if NULL: use hash tracking */)
{
	// Splice this instance before the tail sentinel
	Tcl_MutexLock(&instances->mtx);
	if (inst) {
		struct tracked_instance* i = inst;
		*i = (struct tracked_instance){
			.self = obj,
			.prev = instances->tail.prev,
			.next = &instances->tail,
		};
		i->prev->next = i;
		i->next->prev = i;
	} else {
		int	isnew;
		(void)Tcl_CreateHashEntry(&instances->hashtable, obj, &isnew);
		if (!isnew) Tcl_Panic("Obj %p already registered", (void*)obj);
	}
	Tcl_MutexUnlock(&instances->mtx);
}

void forget_instance(struct tracked_instances* instances, Tcl_Obj* obj, void* inst /* if NULL: use hash tracking */)
{
	Tcl_MutexLock(&instances->mtx);
	if (inst) {
		struct tracked_instance* i = inst;
		i->prev->next = i->next;
		i->next->prev = i->prev;
		i->next = NULL;
		i->prev = NULL;
		i->self = NULL;
	} else {
		Tcl_HashEntry*	he = Tcl_FindHashEntry(&instances->hashtable, obj);
		if (!he) Tcl_Panic("Obj %p not registered", (void*)obj);
		Tcl_DeleteHashEntry(he);
	}
	Tcl_MutexUnlock(&instances->mtx);
}

void init_instance_tracking(struct tracked_instances* instances)
{
	if (!instances->head.next) {
		Tcl_MutexLock(&instances->mtx);
		if (!instances->head.next) {
			instances->head.next = &instances->tail;
			instances->tail.prev = &instances->head;
			Tcl_InitHashTable(&instances->hashtable, TCL_ONE_WORD_KEYS);
		}
		Tcl_MutexUnlock(&instances->mtx);
	}
}

void finalize_instance_tracking(struct tracked_instances* instances)
{
	Tcl_MutexLock(&instances->mtx);
	if (instances->head.next) {
		struct tracked_instance* s = instances->head.next;
		// First pass: ensure everything has a string rep (reduce thrashing during freeintrep pass)
		while (s->next) {
			Tcl_GetString(s->self);	// Ensure string rep exists
			s = s->next;
		}
		// Second pass: remove intrep
		s = instances->head.next;
		while (s->next) {
			Tcl_GetString(s->self);	// Should always be a nop, here in case of pathological free_intrep interactions
			Tcl_FreeInternalRep(s->self);
			s = instances->head.next;
		}

		Tcl_HashSearch	search;
		Tcl_HashEntry*	he = NULL;
		// First pass: ensure everything has a string rep (reduce thrashing during freeintrep pass)
		for (he = Tcl_FirstHashEntry(&instances->hashtable, &search); he; he=Tcl_NextHashEntry(&search)) {
			Tcl_Obj* obj = Tcl_GetHashKey(&instances->hashtable, he);
			Tcl_GetString(obj);
		}
		// Second pass: remove intrep
		while ((he = Tcl_FirstHashEntry(&instances->hashtable, &search))) {
			Tcl_Obj* obj = Tcl_GetHashKey(&instances->hashtable, he);
			Tcl_GetString(obj);	// Should always be a nop, here in case of pathological free_intrep interactions
			Tcl_FreeInternalRep(obj);
		}

		Tcl_DeleteHashTable(&instances->hashtable);
	}
	Tcl_MutexUnlock(&instances->mtx);
	Tcl_MutexFinalize(&instances->mtx);
}

