// DEFINITION MODULE SYSTEM

// --------------------
// prototypes for CAPS/LOWS

# ifdef __Strings_MN

# ifndef _M2INTRINSIC_Strings_
# define _M2INTRINSIC_Strings_

# ifndef _USER_STRINGS_DEFINED_

# ifndef __Strings_MI
# define __Strings_MI_UNDEF
# define __Strings_MI
# endif

namespace Strings {
  __Strings_MI void (CapsA)( CARDINAL HIGH_, CHAR* s ) throw();
  __Strings_MI void (CapsW)( CARDINAL HIGH_, WCHAR* s ) throw();
  __Strings_MI void (LowsA)( CARDINAL HIGH_, CHAR* s ) throw();
  __Strings_MI void (LowsW)( CARDINAL HIGH_, WCHAR* s ) throw();
}
# define __M2CAPA Strings::CapsA
# define __M2CAPW Strings::CapsW
# define __M2LOWA Strings::LowsA
# define __M2LOWW Strings::LowsW

# ifdef __Strings_MI_UNDEF
# undef __Strings_MI
# endif

# endif // _USER_STRINGS_DEFINED_

// procedures
inline void CAPB_( CARDINAL HIGH_, CHAR* ch ) throw()
{
  __M2CAPA( HIGH_, ch );
}
inline void CAPW_( CARDINAL HIGH_, WCHAR* ch ) throw()
{
  __M2CAPW( HIGH_, ch );
}
inline void LOWB_( CARDINAL HIGH_, CHAR* ch ) throw()
{
  __M2LOWA( HIGH_, ch );
}
inline void LOWW_( CARDINAL HIGH_, WCHAR* ch ) throw()
{
  __M2LOWW( HIGH_, ch );
}
// functions
inline CHAR CAPFB_( CHAR ch ) throw()
{
  __M2CAPA( 0, &ch );
  return ch;
}
inline WCHAR CAPFW_( WCHAR ch ) throw()
{
  __M2CAPW( 0, &ch );
  return ch;
}
inline CHAR LOWFB_( CHAR ch ) throw()
{
  __M2LOWA( 0, &ch );
  return ch;
}
inline WCHAR LOWFW_( WCHAR ch ) throw()
{
  __M2LOWW( 0, &ch );
  return ch;
}

# endif // # ifndef _M2INTRINSIC_Strings_

# endif // # ifdef __Strings_MN

// --------------------
// prototypes for new/delete

# ifdef __Storage_MN

# ifndef _M2INTRINSIC_Storage_
# define _M2INTRINSIC_Storage_

# ifndef _USER_STORAGE_DEFINED_

# ifndef __Storage_MI
# define __Storage_MI_UNDEF
# define __Storage_MI
# endif

namespace Storage {
  __Storage_MI void (M2ALLOCATE)( ADDRESS* ptr, CARDINAL size ) throw();
  __Storage_MI void (M2DEALLOCATE)( ADDRESS* ptr ) throw();
}
# define __M2ALLOCATE Storage::M2ALLOCATE
# define __M2DEALLOCATE Storage::M2DEALLOCATE

# ifdef __Storage_MI_UNDEF
# undef __Storage_MI
# endif

# endif // _USER_STORAGE_DEFINED_

inline void* OBJECT::operator new(size_t size) throw()
{
  void* ptr;
  __M2ALLOCATE(&ptr, size);
  return ptr;
} // OBJECT::operator new

inline void OBJECT::operator delete(void* ptr) throw()
{
  __M2DEALLOCATE(&ptr);
} // OBJECT::operator delete

# endif // # ifndef _M2INTRINSIC_Storage_

# endif // # ifdef __Storage_MN

// --------------------
// MODULA-2 ASSERTIONS

# ifndef _M2INTRINSIC_Assert_
# define _M2INTRINSIC_Assert_

#include "m2assert.h"

#define _WIDEN(x) L##x
#define WIDEN(x) _WIDEN(x)
#define _LITERATE(x) L#x
#define LITERATE(x) _LITERATE(x)

# define ASSERT_(e)  M2AssertW( e, WIDEN(__FILE__), LITERATE(__LINE__)) // from m2assert, function is controller by m2cpp emit, not by cl.exe flags
# define ASSERTL_(e) M2AssertLogW( e, WIDEN(__FILE__), LITERATE(__LINE__)) // from m2assert, function is controller by m2cpp emit, not by cl.exe flags

# endif // # ifndef _M2INTRINSIC_Assert_

// --------------------
