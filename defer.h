#ifndef _DEFER_H
#define _DEFER_H

#if HAVE_NATIVE_DEFER
/* Compiler supports _Defer natively (e.g. clang 22+ with -fdefer-ts).
 * Guard against <stdlib.h> already providing this macro per the TS.  */
# ifndef defer
#  define defer _Defer
# endif

#elif HAVE_DEFER_POLYFILL
/* GCC polyfill using nested functions + __attribute__((cleanup)).
 * Credit: Jens Gustedt (author of the C2y defer proposal).
 * Always use braces: defer { ... }                                    */
# define defer _Defer
# define _Defer      _Defer_A(__COUNTER__)
# define _Defer_A(N) _Defer_B(N)
# define _Defer_B(N) _Defer_C(_Defer_func_ ## N, _Defer_var_ ## N)
# define _Defer_C(F, V)                                                \
  _Pragma("GCC diagnostic push")                                       \
  _Pragma("GCC diagnostic ignored \"-Wpedantic\"")                     \
  auto void F(int*);                                                   \
  __attribute__((__cleanup__(F), __deprecated__, __unused__))           \
     int V;                                                            \
  __attribute__((__always_inline__, __deprecated__, __unused__))        \
    inline auto void F(__attribute__((__unused__)) int*V)

#else
# error "No defer support available"
#endif

#endif /* _DEFER_H */
