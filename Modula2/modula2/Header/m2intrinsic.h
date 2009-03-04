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

# ifdef __Debug_MN

# ifndef _M2INTRINSIC_Assert_
# define _M2INTRINSIC_Assert_

# ifndef _USER_DEBUG_DEFINED_

# ifndef __Debug_MI
# define __Debug_MI_UNDEF
# define __Debug_MI
# endif

namespace Debug {
  __Debug_MI BOOLEAN Assert( INTEGER Module_HIGH, const WCHAR* Module, CARDINAL ModuleLine, CARDINAL CPPLine ) throw();
  __Debug_MI void LogAssertA( INTEGER Text_HIGH, const CHAR* Text, INTEGER Module_HIGH, const CHAR* Module, CARDINAL ModuleLine ) throw();
  __Debug_MI void LogAssertW( INTEGER Text_HIGH, const WCHAR* Text, INTEGER Module_HIGH, const WCHAR* Module, CARDINAL ModuleLine ) throw();
}
# define __Assertion Debug::Assert
# define __LogAssertionA Debug::LogAssertA
# define __LogAssertionW Debug::LogAssertW

# ifdef __Debug_MI_UNDEF
# undef __Debug_MI
# endif

# endif // _USER_DEBUG_DEFINED_

#define _WIDEN(x) L##x
#define WIDEN(x) _WIDEN(x)
#define _LITERATE(x) L#x
#define LITERATE(x) _LITERATE(x)

#define PROTOTYPE_IMPORT_C extern "C" __declspec(dllimport)
PROTOTYPE_IMPORT_C void __stdcall DebugBreak();

# define ASSERT_(e, m2line) {\
    if( !(e) ) {\
        if( __Assertion( OA_MAX, WIDEN(__FILE__), m2line, __LINE__ )) {\
            DebugBreak();\
        }\
    }\
}

# endif // # ifndef _M2INTRINSIC_Assert_

# endif // # ifdef __Debug_MN

// --------------------
