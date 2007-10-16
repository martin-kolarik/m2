// DEFINITION MODULE SYSTEM

# pragma once
# ifndef _M2CPP_H_
# define _M2CPP_H_

#include "crtdbg.h" // for assert
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
# define INT_MAX               2147483647 // temporary

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
typedef unsigned __int64       CARD64;
typedef unsigned short         SHORTCARD; // link to CARD16
typedef unsigned int           CARDINAL;
typedef unsigned long          LONGCARD; // link to CARD32

typedef signed char            INT8;
typedef signed short           INT16;
typedef signed int             INT32; // defined in basetsd.h as int
typedef __int64                INT64;
typedef short                  SHORTINT; // link to INT16
typedef int                    INTEGER;
typedef long                   LONGINT; // link to INT32

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
typedef unsigned __int64       QUADWORD;

typedef unsigned char          BITSET8;
typedef unsigned short         BITSET16;
typedef unsigned int           BITSET32;
typedef unsigned __int64       BITSET64;
typedef unsigned int           BITSET;

typedef float                  REAL;
typedef double                 LONGREAL;
typedef void *                 ADDRESS;

# ifdef _BASETSD_H_
typedef CARD_PTR               PTR;
typedef CARD_PTR               CARDPTR;
typedef INT_PTR                INTPTR;
typedef DWORD_PTR              STORPTR;
# elif _WIN64
typedef unsigned __int64       PTR;
typedef unsigned __int64       CARDPTR;
typedef __int64                INTPTR;
typedef unsigned __int64       STORPTR;
# else
typedef unsigned int           PTR;
typedef unsigned int           CARDPTR;
typedef int                    INTPTR;
typedef unsigned int           STORPTR;
# endif

typedef char                   ORD8;
typedef short                  ORD16;
typedef int                    ORD32;
typedef int                    ORDINAL;

typedef CARD32                 SET;
typedef CARD64                 LONGSET;

// pretty winnls CPs
# define CP_UTF16              1200
# define CP_UTF16_BIG_ENDIAN   1201

// MODULA-2 embedded procedures, it can be replaced with procedures and implemenentation (cpp) code
# define ABS_(n)               ((n)>0 ? (n) : -(n))
# define ASSERT_(e)            _ASSERT(e)
# define ODD_(n)               (((n)& 1) == 1)
# define EVEN_(n)              (((n)& 1) == 0)
# define MIN2_(a,b)            ((a)<(b) ? (a) : (b))
# define MAX2_(a,b)            ((a)>(b) ? (a) : (b))
# define TRUNC_(n)             (((INTEGER)(n))) // t stands for float, double or other number type
# define FRAC_(t,n)            (((t)(n)-(t)(INT64)(n))) // t stands for float, double or other number type
# define VAL_(t,n)             ((t)(n))

# define FIELDOFS_(r,f)        ((CARDINAL)&(((r*)0)->f))
# define FIELDOFTYPE_(t,f)     (((t*)0)->f)

# define DECFO_(t,a,b)         ((t)((ORDINAL)(a) - (ORDINAL)(b)))
# define DECFA_(t,a,b)         ((t)((PTR)(a) - (PTR)(b)))
# define INCFO_(t,a,b)         ((t)((ORDINAL)(a) + (ORDINAL)(b)))
# define INCFA_(t,a,b)         ((t)((PTR)(a) + (PTR)(b)))

__forceinline bool __fastcall DEBUGGED_() {
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

inline BYTE LOBYTE_( WORD w ) { return ((__w*)&w)->lo; }
inline BYTE HIBYTE_( WORD w ) { return ((__w*)&w)->hi; }
inline WORD LOWORD_( LONGWORD dw ) { return ((__dw*)&dw)->lo; }
inline WORD HIWORD_( LONGWORD dw ) { return ((__dw*)&dw)->hi; }
inline LONGWORD LOLONGWORD_( QUADWORD qw ) { return ((__qw*)&qw)->lo; }
inline LONGWORD HILONGWORD_( QUADWORD qw ) { return ((__qw*)&qw)->hi; }

// simple swaps
# define SWAPB_(b) (b)
inline WORD SWAPW_( WORD w ) {
  WORD l;
  ((__w*)&l)->lo = ((__w*)&w)->hi;
  ((__w*)&l)->hi = ((__w*)&w)->lo;
  return l;
};
inline LONGWORD SWAPLW_( LONGWORD w ) {
  LONGWORD l;
  ((__dw*)&l)->lo = ((__dw*)&w)->hi;
  ((__dw*)&l)->hi = ((__dw*)&w)->lo;
  return l;
};
inline QUADWORD SWAPQW_( QUADWORD w ) {
  QUADWORD l;
  ((__qw*)&l)->lo = ((__qw*)&w)->hi;
  ((__qw*)&l)->hi = ((__qw*)&w)->lo;
  return l;
};
# ifdef _BASETSD_H_
  # define SWAPPTR_(p) SWAPLW_(p)
# elif _WIN64
  # define SWAPPTR_(p) SWAPQW_(p)
# else
  # define SWAPPTR_(p) SWAPLW_(p)
# endif

// le/be swaps
# define REVERSEB_(b) (b)
inline WORD REVERSEWB_( WORD w ) {
  return SWAPW_( w );
}
inline LONGWORD REVERSELWB_( LONGWORD w ) {
  LONGWORD l;
  ((__dw*)&l)->lo = REVERSEWB_( ((__dw*)&w)->hi );
  ((__dw*)&l)->hi = REVERSEWB_( ((__dw*)&w)->lo );
  return l;
}
inline QUADWORD REVERSEQWB_( QUADWORD w ) {
  QUADWORD l;
  ((__qw*)&l)->lo = REVERSELWB_( ((__qw*)&w)->hi );
  ((__qw*)&l)->hi = REVERSELWB_( ((__qw*)&w)->lo );
  return l;
}
# ifdef _BASETSD_H_
  # define REVERSEPTRB_(p) REVERSELWB_(p)
# elif _WIN64
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
    (s) |= 1UI64 << __e; \
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
    (s) &= ~(1UI64 << __e); \
  } \
}
# define EXCLA_(s,l,b) { \
  unsigned int __e = (b); \
  if (__e <= (l)) { \
    (s)[b/8] &= ~(1 << (__e&7)); \
  } \
}

// sets -- test
inline bool INS_( SET s, SET l, SET b )
{
  if (b<=l) {
    return (s & (1<<b)) != 0;
  } else {
    return false;
  }
}

inline bool INL_( LONGSET s, SET l, SET b )
{
  if (b<=l) {
    return (s & (1UI64<<b)) != 0;
  } else {
    return false;
  }
}

inline bool INA_( BYTE* s, SET l, SET b )
{
  if (b<=l) {
    return (s[b/8] & (1<<(b&7))) != 0;
  } else {
    return false;
  }
}
//... a pair to simply solve CONST, the casting should be in m2cpp ???
inline bool INA_( const BYTE* s, SET l, SET b )
{
  return INA_( (BYTE*)s, l, b );
}

// sets -- conjunction
inline void SCONJA_( CARDINAL L, BYTE* R, const BYTE* S1, const BYTE* S2 )
{
  for(CARDINAL i = 0; i < L; i++) {
    R[i] = S1[i] & S2[i];
  }
}
// sets -- disjunction
inline void SDISJA_( CARDINAL L, BYTE* R, const BYTE* S1, const BYTE* S2 )
{
  for(CARDINAL i = 0; i < L; i++) {
    R[i] = S1[i] | S2[i];
  }
}
// sets -- difference
inline void SDIFFA_( CARDINAL L, BYTE* R, const BYTE* S1, const BYTE* S2 )
{
  for(CARDINAL i = 0; i < L; i++) {
    R[i] = S1[i] &~ S2[i];
  }
}
// sets -- symmetric difference
inline void SSYMDA_( CARDINAL L, BYTE* R, const BYTE* S1, const BYTE* S2 )
{
  for(CARDINAL i = 0; i < L; i++) {
    R[i] = S1[i] ^ S2[i];
  }
}
// sets -- assigning literal to long set
#define ASSIGNS_( d, s ) ((*(CARD32*)&(d)) = (s))

// binaries -- EQUALS
inline BOOLEAN EQUALSM_(const BYTE* S1, const BYTE* S2, CARDINAL L)
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
inline BOOLEAN INSIDEB_(CARDINAL HIGH_, const CHAR* S, ORDINAL I)
{
  return I <= HIGH_ && S[I] != 0;
}
// strings -- LASTCHAR UNICODE
inline BOOLEAN INSIDEW_(CARDINAL HIGH_, const WCHAR* S, ORDINAL I)
{
  return I <= HIGH_ && S[I] != 0;
}

// strings -- LENGTH ANSI
inline CARDINAL LENGTHB_(CARDINAL HIGH_, const CHAR* S)
{
  CHAR* a;
  ADDRESS t;

  if (S == 0 || HIGH_ == -1) {
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
inline CARDINAL LENGTHW_(CARDINAL HIGH_, const WCHAR* S)
{
  WCHAR* a;
  ADDRESS t;

  if (S == 0 || HIGH_ == -1) {
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
inline CARDINAL LENGTHszB_(const CHAR* S)
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
inline CARDINAL LENGTHszW_(const WCHAR* S)
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
inline BOOLEAN EQUALSB_(CARDINAL HIGH_1, const CHAR* S1, CARDINAL HIGH_2, const CHAR* S2)
{
  ADDRESS t1;

  if (S1 == 0 || HIGH_1 == -1 || S2 == 0 || HIGH_2 == -1) {
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
inline BOOLEAN EQUALSW_(CARDINAL HIGH_1, const WCHAR* S1, CARDINAL HIGH_2, const WCHAR* S2)
{
  ADDRESS t1;

  if (S1 == 0 || HIGH_1 == -1 || S2 == 0 || HIGH_2 == -1) {
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
inline void ASSIGNB_(CARDINAL HIGH_D, CHAR* D, CARDINAL HIGH_S, const CHAR* S)
{
  ADDRESS ts;

  if (D == 0 || HIGH_D == -1) {
     return;
  } else if (S == 0 || HIGH_S == -1) {
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
inline void ASSIGNW_(CARDINAL HIGH_D, WCHAR* D, CARDINAL HIGH_S, const WCHAR* S)
{
  ADDRESS ts;

  if (D == 0 || HIGH_D == -1) {
     return;
  } else if (S == 0 || HIGH_S == -1) {
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
inline void ASSIGNszB_(CARDINAL HIGH_D, CHAR* D, const CHAR* S)
{
  ADDRESS ts;

  if (D == 0 || HIGH_D == -1) {
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
inline void ASSIGNszW_(CARDINAL HIGH_D, WCHAR* D, const WCHAR* S)
{
  ADDRESS ts;

  if (D == 0 || HIGH_D == -1) {
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

# endif // ifndef _M2CPP_H_
