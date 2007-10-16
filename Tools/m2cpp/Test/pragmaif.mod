MODULE pragmaif;

CONST
   C1 = TRUE;
   C2 = TRUE;
   C3 = FALSE;
   S0 = C"XX";
   S1 = L"XX";
   S2 = L"YY";
   
TYPE
  TE = (
    en0
    #if C1 #then
      , enA
    #endif
    #if C3 #then
      , enB
    #endif
    #if C1 #then
      , enC
    #endif
    #if C3 #then
      , enD3
    #elsif C1 #then
      , enD1
    #endif
  );

VAR // should be defined V1, V2, V8, V10 by cmd line, V11, V12, V13, V14
#if C1 #then
   V1 : BOOLEAN;
#endif   
#if C1 #and C2 #then
   V2 : BOOLEAN;
#endif   
// #if C1 #or S1 #then
//   V3 : BOOLEAN;
// #endif   
// #if C1 #and S1 #then
//    V4 : BOOLEAN;
// #endif   
// #if S1 #or S2 #then
//    V5 : BOOLEAN;
// #endif   
// #if S1 #and S2 #then
//    V6 : BOOLEAN;
// #endif   
#if S1 = S2 #then
   V7 : BOOLEAN;
#endif   
#if S1 <> S2 #then
   V8 : BOOLEAN;
#endif   
// #if S0 = S1 #then
//    V9 : BOOLEAN;
// #endif
#if #defined CMDLINE #then
   #if S1 = CMDLINE #then
      V10 : BOOLEAN;
   #endif
#endif
#if #contains( S1, L"X" ) #then
   V11 : BOOLEAN;
#endif
#if #startswith( S1, L"X" ) #then
   V12 : BOOLEAN;
#endif
#if S1 #contains L"X" #then
   V13 : BOOLEAN;
#endif
#if S1 #startswith L"X" #then
   V14 : BOOLEAN;
#endif

#if #defined CMDLINE #then
CONST
   // S3 = S1 + CMDLINE;
   S4 = CMDLINE;
#endif

END pragmaif.