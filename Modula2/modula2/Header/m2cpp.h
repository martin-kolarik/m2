// DEFINITION MODULE SYSTEM

# pragma once
# ifndef _M2CPP_H_
# define _M2CPP_H_

#include "m2init.h" // for module initialization

// common directives
# define __DLL_EXPORT          __declspec(dllexport)
# define __DLL_IMPORT          __declspec(dllimport)
# define __DLL_EMBED

// common constants
# define False                 0
# define FALSE                 0
# define True                  1
# define TRUE                  1
# define NIL                   0
# define OA_MAX                2147483647

# define OUT
# define IN

// common types
# ifndef _HRESULT_DEFINED
# define _HRESULT_DEFINED
typedef long                   HRESULT; // for COM PROCEDURE...
# endif

typedef unsigned char          CARD8;
typedef unsigned short         CARD16;
typedef unsigned int           CARD32;
typedef unsigned long long     CARD64;
typedef CARD16                 SHORTCARD; // link to CARD16
typedef CARD32                 CARDINAL;
typedef unsigned long          LONGCARD; // explicitely long

typedef signed char            INT8;
typedef signed short           INT16;
typedef signed int             INT32; // defined in basetsd.h as int
typedef signed long long       INT64;
typedef INT16                  SHORTINT; // link to INT16
typedef INT32                  INTEGER;
typedef signed long            LONGINT; // explicitely long

typedef unsigned char          BOOLEAN;
typedef signed char            TRISTATE;
typedef char                   CHAR;
# ifdef _WCHAR_T_DEFINED
  typedef wchar_t              WCHAR;
# else
  typedef unsigned short       WCHAR;
# endif

typedef unsigned char          BYTE;
typedef unsigned short         WORD;
typedef unsigned long          LONGWORD;
typedef unsigned long long     QUADWORD;

typedef unsigned char          BITSET8;
typedef unsigned short         BITSET16;
typedef unsigned long          BITSET32;
typedef unsigned long long     BITSET64;
typedef unsigned long          BITSET;

typedef float                  REAL;
typedef double                 LONGREAL;
// typedef void *                 ADDRESS;
#define ADDRESS                void*

# ifdef _WIN64
typedef CARD64                 PTR;
typedef CARD64                 CARDPTR;
typedef INT64                  INTPTR;
typedef CARD64                 STORPTR;
# else
typedef CARD32                 PTR;
typedef CARD32                 CARDPTR;
typedef INT32                  INTPTR;
typedef CARD32                 STORPTR;
# endif

typedef char                   ORD8;
typedef short                  ORD16;
typedef long                   ORD32;
typedef ORD32                  ORDINAL;

typedef CARD32                 SET;
typedef CARD64                 LONGSET;

// pretty winnls CPs
# define CP_UTF16              1200
# define CP_UTF16_BIG_ENDIAN   1201

// MODULA-2 embedded procedures, it can be replaced with procedures and implemenentation (cpp) code
# define ABS_(n)               ((n)>0 ? (n) : -(n))
# define ODD_(n)               (((n)& 1) == 1)
# define EVEN_(n)              (((n)& 1) == 0)
# define MIN2_(a,b)            ((a)<(b) ? (a) : (b))
# define MAX2_(a,b)            ((a)>(b) ? (a) : (b))
# define TRUNC_(n)             (((INTEGER)(n)))
# define FRAC_(t,n)            (((t)(n)-(t)(INT64)(n))) // t stands for float, double or other number type
# define VAL_(t,n)             ((t)(n))

# define FIELDOFS_(r,f)        ((CARDINAL)&(((r*)0)->f))
# define FIELDOFTYPE_(t,f)     (((t*)0)->f)

# define DECFO_(t,a,b)         ((t)((ORDINAL)(a) - (ORDINAL)(b)))
# define DECFA_(t,a,b)         ((t)((PTR)(a) - (PTR)(b)))
# define INCFO_(t,a,b)         ((t)((ORDINAL)(a) + (ORDINAL)(b)))
# define INCFA_(t,a,b)         ((t)((PTR)(a) + (PTR)(b)))

__forceinline bool __fastcall DEBUGGED_() throw() {
  __asm {
    mov eax, dword ptr fs:[0x18]
    mov eax, dword ptr [eax+0x30]
    movzx eax, byte ptr [eax+2]
  }
}

// bytes, words, longwords, ...
#pragma pack(push, 1)
typedef struct { BYTE lo; BYTE hi; } __w;
typedef struct { WORD lo; WORD hi; } __dw;
typedef struct { LONGWORD lo; LONGWORD hi; } __qw;
#pragma pack(pop)

inline BYTE LOBYTE_( WORD w ) throw() { return ((__w*)&w)->lo; }
inline BYTE HIBYTE_( WORD w ) throw() { return ((__w*)&w)->hi; }
inline WORD LOWORD_( LONGWORD dw ) throw() { return ((__dw*)&dw)->lo; }
inline WORD HIWORD_( LONGWORD dw ) throw() { return ((__dw*)&dw)->hi; }
inline LONGWORD LOLONGWORD_( QUADWORD qw ) throw() { return ((__qw*)&qw)->lo; }
inline LONGWORD HILONGWORD_( QUADWORD qw ) throw() { return ((__qw*)&qw)->hi; }
# ifdef _WIN64
   inline LONGWORD LOPTRLONGWORD_( PTR ptr ) throw() { return ((__qw*)&ptr)->lo; }
   inline LONGWORD HIPTRLONGWORD_( PTR ptr ) throw() { return ((__qw*)&ptr)->hi; }
# else
   inline LONGWORD LOPTRLONGWORD_( PTR ptr ) { return (LONGWORD)ptr; }
   inline LONGWORD HIPTRLONGWORD_( PTR ptr ) { return (LONGWORD)0; }
# endif

// simple swaps
# define SWAPB_(b) (b)
inline WORD SWAPW_( WORD w ) throw() {
  WORD l;
  ((__w*)&l)->lo = ((__w*)&w)->hi;
  ((__w*)&l)->hi = ((__w*)&w)->lo;
  return l;
};
inline LONGWORD SWAPLW_( LONGWORD w ) throw() {
  LONGWORD l;
  ((__dw*)&l)->lo = ((__dw*)&w)->hi;
  ((__dw*)&l)->hi = ((__dw*)&w)->lo;
  return l;
};
inline QUADWORD SWAPQW_( QUADWORD w ) throw() {
  QUADWORD l;
  ((__qw*)&l)->lo = ((__qw*)&w)->hi;
  ((__qw*)&l)->hi = ((__qw*)&w)->lo;
  return l;
};
# ifdef _WIN64
  # define SWAPPTR_(p) SWAPQW_(p)
# else
  # define SWAPPTR_(p) SWAPLW_(p)
# endif

// le/be swaps
# define REVERSEB_(b) (b)
inline WORD REVERSEWB_( WORD w ) throw() {
  return SWAPW_( w );
}
inline LONGWORD REVERSELWB_( LONGWORD w ) throw() {
  LONGWORD l;
  ((__dw*)&l)->lo = REVERSEWB_( ((__dw*)&w)->hi );
  ((__dw*)&l)->hi = REVERSEWB_( ((__dw*)&w)->lo );
  return l;
}
inline QUADWORD REVERSEQWB_( QUADWORD w ) throw() {
  QUADWORD l;
  ((__qw*)&l)->lo = REVERSELWB_( ((__qw*)&w)->hi );
  ((__qw*)&l)->hi = REVERSELWB_( ((__qw*)&w)->lo );
  return l;
}
# ifdef _WIN64
  # define REVERSEPTRB_(p) REVERSEQWB_(p)
# else
  # define REVERSEPTRB_(p) REVERSELWB_(p)
# endif

// sets -- inclusion
# define INCLS_(s,l,b) { \
  unsigned int __e = (b); \
  if (__e <= (l)) { \
    (s) |= 1 << __e; \
  } \
}
# define INCLL_(s,l,b) { \
  unsigned int __e = (b); \
  if (__e <= (l)) { \
    (s) |= 1ull << __e; \
  } \
}
# define INCLA_(s,l,b) { \
  unsigned int __e = (b); \
  if (__e <= (l)) { \
    (s)[b/8] |= 1 << (__e&7); \
  } \
}

// sets -- exclusion
# define EXCLS_(s,l,b) { \
  unsigned int __e = (b); \
  if (__e <= (l)) { \
    (s) &= ~(1 << __e); \
  } \
}
# define EXCLL_(s,l,b) { \
  unsigned int __e = (b); \
  if (__e <= (l)) { \
    (s) &= ~(1ull << __e); \
  } \
}
# define EXCLA_(s,l,b) { \
  unsigned int __e = (b); \
  if (__e <= (l)) { \
    (s)[b/8] &= ~(1 << (__e&7)); \
  } \
}

// sets -- test
inline bool INS_( SET s, SET l, SET b ) throw()
{
  if (b<=l) {
    return (s & (1<<b)) != 0;
  } else {
    return false;
  }
}

inline bool INL_( LONGSET s, SET l, SET b ) throw()
{
  if (b<=l) {
    return (s & (1ull<<b)) != 0;
  } else {
    return false;
  }
}

inline bool INA_( BYTE* s, SET l, SET b ) throw()
{
  if (b<=l) {
    return (s[b/8] & (1<<(b&7))) != 0;
  } else {
    return false;
  }
}
//... a pair to simply solve CONST, the casting should be in m2cpp ???
inline bool INA_( const BYTE* s, SET l, SET b ) throw()
{
  return INA_( (BYTE*)s, l, b );
}

// sets -- conjunction
inline void SCONJA_( CARDINAL L, BYTE* R, const BYTE* S1, const BYTE* S2 ) throw()
{
  for(CARDINAL i = 0; i < L; i++) {
    R[i] = S1[i] & S2[i];
  }
}
// sets -- disjunction
inline void SDISJA_( CARDINAL L, BYTE* R, const BYTE* S1, const BYTE* S2 ) throw()
{
  for(CARDINAL i = 0; i < L; i++) {
    R[i] = S1[i] | S2[i];
  }
}
// sets -- difference
inline void SDIFFA_( CARDINAL L, BYTE* R, const BYTE* S1, const BYTE* S2 ) throw()
{
  for(CARDINAL i = 0; i < L; i++) {
    R[i] = S1[i] &~ S2[i];
  }
}
// sets -- symmetric difference
inline void SSYMDA_( CARDINAL L, BYTE* R, const BYTE* S1, const BYTE* S2 ) throw()
{
  for(CARDINAL i = 0; i < L; i++) {
    R[i] = S1[i] ^ S2[i];
  }
}
// sets -- assigning literal to long set
#define ASSIGNS_( d, s ) ((*(CARD32*)&(d)) = (s))

// binaries -- EQUALS
inline BOOLEAN EQUALSM_(const BYTE* S1, const BYTE* S2, CARDINAL L) throw()
{
  ADDRESS t1;

  t1 = (ADDRESS)((PTR)S1 + L);
  for(;;) {
     if ((ADDRESS)S1 == t1) {
       return TRUE;
     } else if ((*S1) != (*S2)) {
       return FALSE;
     }
     S1++;
     S2++;
  }
}

// strings -- INSIDE ANSI
inline BOOLEAN INSIDEB_(INTEGER HIGH_, const CHAR* S, ORDINAL I) throw()
{
  return I <= HIGH_ && S[I] != 0;
}
// strings -- INSIDE UNICODE
inline BOOLEAN INSIDEW_(INTEGER HIGH_, const WCHAR* S, ORDINAL I) throw()
{
  return I <= HIGH_ && S[I] != 0;
}

// strings -- LENGTH ANSI
inline CARDINAL LENGTHB_(INTEGER HIGH_, const CHAR* S) throw()
{
  CHAR* a;
  ADDRESS t;

  if (S == 0 || HIGH_ < 0) {
     return 0;
  }
  t = (ADDRESS)((PTR)S + HIGH_ + 1);
  a = (CHAR *)S;
  for(;;) {
     if ((*a) == '\x0') {
       return (CARDINAL)((PTR)a - (PTR)S);
     }
     a++;
     if (a == t) {
       return (CARDINAL)((PTR)a - (PTR)S);
     }
  }
}
// strings -- LENGTH UNICODE
inline CARDINAL LENGTHW_(INTEGER HIGH_, const WCHAR* S) throw()
{
  WCHAR* a;
  ADDRESS t;

  if (S == 0 || HIGH_ < 0) {
     return 0;
  }
  t = (ADDRESS)((PTR)S + (HIGH_ << 1) + 2);
  a = (WCHAR *)S;
  for(;;) {
     if ((*a) == L'\x0') {
       return (CARDINAL)((PTR)a - (PTR)S) >> 1;
     }
     a++;
     if (a == t) {
       return (CARDINAL)((PTR)a - (PTR)S) >> 1;
     }
  }
}
// strings -- LENGTH zero terminated ANSI
inline CARDINAL LENGTHszB_(const CHAR* S) throw()
{
  CHAR* a;

  if (S == 0) {
     return 0;
  };
  a = (CHAR *)S;
  for(;;) {
     if ((*a) == '\x0') {
       return (CARDINAL)((PTR)a - (PTR)S);
     }
     a++;
  }
}
// strings -- LENGTH zero terminated UNICODE
inline CARDINAL LENGTHszW_(const WCHAR* S) throw()
{
  WCHAR* a;

  if (S == 0) {
      return 0;
  };
  a = (WCHAR *)S;
  for(;;) {
     if ((*a) == L'\x0') {
       return (CARDINAL)((PTR)a - (PTR)S) >> 1;
     }
     a++;
  }
}
// strings -- EQUALS ANSI
inline BOOLEAN EQUALSB_(INTEGER HIGH_1, const CHAR* S1, INTEGER HIGH_2, const CHAR* S2) throw()
{
  ADDRESS t1;

  if (S1 == 0 || HIGH_1 < 0 || S2 == 0 || HIGH_2 < 0) {
     return FALSE;
  }
  if (HIGH_1 < HIGH_2) {
     t1 = (ADDRESS)((PTR)S1 + HIGH_1 + 1);
  } else {
     t1 = (ADDRESS)((PTR)S1 + HIGH_2 + 1);
  }
  for(;;) {
     if ((*S1) != (*S2)) {
       return FALSE;
     } else if ((*S1) == '\x0') {
       return TRUE;
     }
     S1++;
     S2++;
     if ((ADDRESS)S1 == t1) {
       if (HIGH_1 < HIGH_2) {
         return (*S2) == '\x0';
       } else if (HIGH_1 > HIGH_2) {
         return (*S1) == '\x0';
       } else {
         return TRUE;
       }
     }
  }
}
// strings -- EQUALS UNICODE
inline BOOLEAN EQUALSW_(INTEGER HIGH_1, const WCHAR* S1, INTEGER HIGH_2, const WCHAR* S2) throw()
{
  ADDRESS t1;

  if (S1 == 0 || HIGH_1 < 0 || S2 == 0 || HIGH_2 < 0) {
     return FALSE;
  }
  if (HIGH_1 < HIGH_2) {
     t1 = (ADDRESS)((PTR)S1 + (HIGH_1 << 1) + 2);
  } else {
     t1 = (ADDRESS)((PTR)S1 + (HIGH_2 << 1) + 2);
  }
  for(;;) {
     if ((*S1) != (*S2)) {
       return FALSE;
     } else if ((*S1) == L'\x0') {
       return TRUE;
     }
     S1++;
     S2++;
     if ((ADDRESS)S1 == t1) {
       if (HIGH_1 < HIGH_2) {
         return (*S2) == L'\x0';
       } else if (HIGH_1 > HIGH_2) {
         return (*S1) == L'\x0';
       } else {
         return TRUE;
       }
     }
  }
}
// strings -- ASSIGN ANSI
inline void ASSIGNB_(INTEGER HIGH_D, CHAR* D, INTEGER HIGH_S, const CHAR* S) throw()
{
  ADDRESS ts;

  if (D == 0 || HIGH_D < 0) {
     return;
  } else if (S == 0 || HIGH_S < 0) {
     (*D) = '\x0';
     return;
  } else if (HIGH_D < HIGH_S) {
     ts = (ADDRESS)((PTR)S + HIGH_D + 1);
  } else {
     ts = (ADDRESS)((PTR)S + HIGH_S + 1);
  }
  for(;;) {
     if ((*S) == '\x0') {
       (*D) = '\x0';
       return;
     } else {
       (*D) = (*S);
     }
     S++;
     D++;
     if ((ADDRESS)S == ts) {
       if (HIGH_D > HIGH_S) {
         (*D) = '\x0';
       }
       return;
     }
  }
}
// strings -- ASSIGN UNICODE
inline void ASSIGNW_(INTEGER HIGH_D, WCHAR* D, INTEGER HIGH_S, const WCHAR* S) throw()
{
  ADDRESS ts;

  if (D == 0 || HIGH_D < 0 ) {
     return;
  } else if (S == 0 || HIGH_S < 0) {
    (*D) = L'\x0';
     return;
  } else if (HIGH_D < HIGH_S) {
     ts = (ADDRESS)((PTR)S + (HIGH_D << 1) + 2);
  } else {
     ts = (ADDRESS)((PTR)S + (HIGH_S << 1) + 2);
  }
  for(;;) {
     if ((*S) == L'\x0') {
       (*D) = L'\x0';
       return;
     } else {
       (*D) = (*S);
     }
     S++;
     D++;
     if ((ADDRESS)S == ts) {
       if (HIGH_D > HIGH_S) {
         (*D) = L'\x0';
       }
       return;
     }
  }
}
// strings -- ASSIGN zero terminated ANSI
inline void ASSIGNszB_(INTEGER HIGH_D, CHAR* D, const CHAR* S) throw()
{
  ADDRESS ts;

  if (D == 0 || HIGH_D < 0) {
     return;
  } else if (S == 0) {
      (*D) = '\x0';;
     return;
  };
  ts = (ADDRESS)((PTR)S + HIGH_D + 1);
  for(;;) {
     if ((*S) == '\x0') {
       (*D) = '\x0';
       return;
     } else {
       (*D) = (*S);
     }
     S++;
     D++;
     if ((ADDRESS)S == ts) {
       return;
     }
  }
}
// strings -- ASSIGN UNICODE
inline void ASSIGNszW_(INTEGER HIGH_D, WCHAR* D, const WCHAR* S) throw()
{
  ADDRESS ts;

  if (D == 0 || HIGH_D < 0) {
     return;
  } else if (S == 0) {
     (*D) = L'\x0';;
     return;
  };
  ts = (ADDRESS)((PTR)S + (HIGH_D << 1) + 2);
  for(;;) {
     if ((*S) == L'\x0') {
       (*D) = L'\x0';
       return;
     } else {
       (*D) = (*S);
     }
     S++;
     D++;
     if ((ADDRESS)S == ts) {
       return;
     }
  }
}

// --------------------
// common class

class OBJECT { public:
  void* operator new(size_t size) throw();
  void operator delete(void* ptr) throw();
}; // OBJECT

// --------------------
// RTTI

struct RTTI
{
    const CHAR* self;
    CARDINAL ancestor_count;
    const RTTI* const* ancestors;
};

#define RTTI_IS_RTTI(classRtti,testRtti) ((classRtti)==(testRtti))
#define RTTI_IS_NAME(classRtti,high,s) (EQUALSB_( OA_MAX, (*classRtti).self, high, (const CHAR*)s ))

inline BOOLEAN RTTI_INHERITS_RTTI( const RTTI* classRtti, const RTTI* testRtti, BOOLEAN checkSelf )
{
    if( checkSelf && RTTI_IS_RTTI( classRtti, testRtti ))
    {
        return TRUE;
    }
    for( INTEGER i = 0; i < classRtti->ancestor_count; i++ )
    {
        if( classRtti->ancestors[i] == testRtti )
        {
            return TRUE;
        }
    }
    for( INTEGER i = 0; i < classRtti->ancestor_count; i++ )
    {
        if( RTTI_INHERITS_RTTI( classRtti->ancestors[i], testRtti, FALSE ))
        {
            return TRUE;
        }
    }
    return FALSE;
}

inline BOOLEAN RTTI_INHERITS_NAME( const RTTI* classRtti, INTEGER HIGH_S, CHAR* S, BOOLEAN checkSelf )
{
    if( checkSelf && RTTI_IS_NAME( classRtti, HIGH_S, S ))
    {
        return TRUE;
    }
    for( INTEGER i = 0; i < classRtti->ancestor_count; i++ )
    {
        if( EQUALSB_( OA_MAX, (*classRtti->ancestors[i]).self, HIGH_S, (const CHAR*)S ))
        {
            return TRUE;
        }
    }
    for( INTEGER i = 0; i < classRtti->ancestor_count; i++ )
    {
        if( RTTI_INHERITS_NAME( classRtti->ancestors[i], HIGH_S, S, FALSE ))
        {
            return TRUE;
        }
    }
    return FALSE;
}

// --------------------

# endif // ifndef _M2CPP_H_
