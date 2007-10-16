// DEFINITION MODULE SYSTEM
// modules initialization

# pragma once
# ifndef _M2INIT_H_
# define _M2INIT_H_

// definitions
# pragma section( ".m2$initA",    long, read )
# pragma section( ".m2$initProc", long, read ) // alphabetically between A and Z
# pragma section( ".m2$initZ",    long, read )

# pragma section( ".m2$doneA",    long, read )
# pragma section( ".m2$doneProc", long, read ) // alphabetically between A and Z
# pragma section( ".m2$doneZ",    long, read )

# define __INIT_SECT __declspec(allocate(".m2$initProc")) 
# define __DONE_SECT __declspec(allocate(".m2$doneProc")) 

// some implementations stuff
typedef void (*__m2_cdtor_proc)(void);

# define __INIT_SYMBOL( s ) \
   static __INIT_SECT __m2_cdtor_proc __m2_init_adr[] = { &s };


# define __DONE_SYMBOL( s ) \
   static __DONE_SECT __m2_cdtor_proc __m2_done_adr[] = { &s };

# endif // ifndef _M2INIT_H_
