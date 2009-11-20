// MODULE INITIALIZATION

# include "m2init.h"

// initialization
# pragma comment(linker, "/merge:.m2=.rdata")

# pragma section( ".CRT$XCV", long, read )
# define __AFTER_CTOR __declspec(allocate(".CRT$XCV")) 

# define __INIT_FIRST __declspec(allocate(".m2$initA")) 
# define __INIT_LAST  __declspec(allocate(".m2$initZ")) 
# define __DONE_FIRST __declspec(allocate(".m2$doneA")) 
# define __DONE_LAST  __declspec(allocate(".m2$doneZ")) 

typedef void (__cdecl *__c_cdtor_proc)(void);

__INIT_FIRST __m2_cdtor_proc _m2_ia[] = { 0 };
__INIT_LAST  __m2_cdtor_proc _m2_iz[] = { 0 };
__DONE_FIRST __m2_cdtor_proc _m2_da[] = { 0 };
__DONE_LAST  __m2_cdtor_proc _m2_dz[] = { 0 };

// routines forwards
void __cdecl __m2_init();
void __cdecl __m2_done();

// chaining variable
static __AFTER_CTOR __c_cdtor_proc __m2_init_adr[] = { &__m2_init };

// implementations
void __cdecl __m2_init()
{
   __m2_cdtor_proc* pproc = _m2_ia;
   while (pproc < _m2_iz)
   {
      if (*pproc != 0)
      {
         (**pproc)();
      }
      pproc++;
   }
   atexit( __m2_done );
}

void __cdecl __m2_done()
{
   __m2_cdtor_proc* pproc = _m2_da;
   while (pproc < _m2_dz)
   {
      if (*pproc != 0)
      {
         (**pproc)();
      }
      pproc++;
   }
}

