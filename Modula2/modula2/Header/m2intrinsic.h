// DEFINITION MODULE SYSTEM

# pragma once
# ifndef _M2INTRINSIC_H_
# define _M2INTRINSIC_H_

# undef __IFACE_UNKNOWN
# ifndef __IFACE
# define __IFACE_UNKNOWN
# define __IFACE
# endif

// --------------------

// prototypes for new/delete
# ifndef _USER_STRINGS_DEFINED_

namespace Strings {
  __IFACE void (CapsA)( CARDINAL HIGH_, CHAR* s );
  __IFACE void (CapsW)( CARDINAL HIGH_, WCHAR* s );
  __IFACE void (LowsA)( CARDINAL HIGH_, CHAR* s );
  __IFACE void (LowsW)( CARDINAL HIGH_, WCHAR* s );
}
# define __M2CAPA Strings::CapsA
# define __M2CAPW Strings::CapsW
# define __M2LOWA Strings::LowsA
# define __M2LOWW Strings::LowsW

# endif

// procedures
inline void CAPB_( CARDINAL HIGH_, CHAR* ch )
{
  __M2CAPA( HIGH_, ch );
}
inline void CAPW_( CARDINAL HIGH_, WCHAR* ch )
{
  __M2CAPW( HIGH_, ch );
}
inline void LOWB_( CARDINAL HIGH_, CHAR* ch )
{
  __M2LOWA( HIGH_, ch );
}
inline void LOWW_( CARDINAL HIGH_, WCHAR* ch )
{
  __M2LOWW( HIGH_, ch );
}
// functions
inline CHAR CAPFB_( CHAR ch )
{
  __M2CAPA( 0, &ch );
  return ch;
}
inline WCHAR CAPFW_( WCHAR ch )
{
  __M2CAPW( 0, &ch );
  return ch;
}
inline CHAR LOWFB_( CHAR ch )
{
  __M2LOWA( 0, &ch );
  return ch;
}
inline WCHAR LOWFW_( WCHAR ch )
{
  __M2LOWW( 0, &ch );
  return ch;
}

// --------------------

// common class
class OBJECT { public:
  void* operator new(size_t size);
  void operator delete(void* ptr);
}; // OBJECT

// prototypes for new/delete
# ifndef _USER_STORAGE_DEFINED_

namespace Storage {
  __IFACE void (M2ALLOCATE)( ADDRESS* ptr, CARDINAL size );
  __IFACE void (M2DEALLOCATE)( ADDRESS* ptr );
}
# define __M2ALLOCATE Storage::M2ALLOCATE
# define __M2DEALLOCATE Storage::M2DEALLOCATE

# endif

inline void* OBJECT::operator new(size_t size)
{
  void* ptr;
  __M2ALLOCATE(&ptr, size);
  return ptr;
} // OBJECT::operator new

inline void OBJECT::operator delete(void* ptr)
{
  __M2DEALLOCATE(&ptr);
} // OBJECT::operator delete

// --------------------

# ifdef __IFACE_UNKNOWN
# undef __IFACE
# endif

// --------------------

# endif // ifndef _M2INTRINSIC_H_
