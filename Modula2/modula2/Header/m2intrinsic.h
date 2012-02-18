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
  __Strings_MI void (CapsA)( INTEGER HIGH_, CHAR* s ) throw();
  __Strings_MI void (CapsW)( INTEGER HIGH_, WCHAR* s ) throw();
  __Strings_MI void (LowsA)( INTEGER HIGH_, CHAR* s ) throw();
  __Strings_MI void (LowsW)( INTEGER HIGH_, WCHAR* s ) throw();
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
inline void CAPB_( INTEGER HIGH_, CHAR* ch ) throw()
{
  __M2CAPA( HIGH_, ch );
}
inline void CAPW_( INTEGER HIGH_, WCHAR* ch ) throw()
{
  __M2CAPW( HIGH_, ch );
}
inline void LOWB_( INTEGER HIGH_, CHAR* ch ) throw()
{
  __M2LOWA( HIGH_, ch );
}
inline void LOWW_( INTEGER HIGH_, WCHAR* ch ) throw()
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
  __Storage_MI void (M2ALLOCATE)( M2ADDRESS* ptr, TSIZE size ) throw();
  __Storage_MI void (M2DEALLOCATE)( M2ADDRESS* ptr ) throw();
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

inline void* __cdecl operator new(size_t size) throw()
{
  void* ptr;
  __M2ALLOCATE(&ptr, size);
  return ptr;
}

inline void __cdecl operator delete(void* ptr) throw()
{
  __M2DEALLOCATE(&ptr);
}

inline void* __cdecl operator new[](size_t size) throw()
{
  void* ptr;
  __M2ALLOCATE(&ptr, size);
  return ptr;
}

inline void __cdecl operator delete[](void* ptr) throw()
{
  __M2DEALLOCATE(&ptr);
}

# endif // # ifndef _M2INTRINSIC_Storage_

# endif // # ifdef __Storage_MN

// --------------------
