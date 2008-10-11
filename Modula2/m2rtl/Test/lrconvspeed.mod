MODULE lrconvspeed;

// mii: 3.7, cpp: 2.6, sc: 0.52

IMPORT
   lrconv,
//   Str,
   Strings,
   Time,
   windows;

(*  
IMPORT
  math;

TYPE
   TPow10 = ARRAY [-323..308] OF LONGREAL;
CONST
   pow10 = TPow10(
               1.0E-323, 1.0E-322, 1.0E-321, 1.0E-320, 1.0E-319, 1.0E-318, 1.0E-317, 1.0E-316, 1.0E-315, 1.0E-314, 
               1.0E-313, 1.0E-312, 1.0E-311, 1.0E-310, 1.0E-309, 1.0E-308, 1.0E-307, 1.0E-306, 1.0E-305, 1.0E-304, 
               1.0E-303, 1.0E-302, 1.0E-301, 1.0E-300, 1.0E-299, 1.0E-298, 1.0E-297, 1.0E-296, 1.0E-295, 1.0E-294, 
               1.0E-293, 1.0E-292, 1.0E-291, 1.0E-290, 1.0E-289, 1.0E-288, 1.0E-287, 1.0E-286, 1.0E-285, 1.0E-284, 
               1.0E-283, 1.0E-282, 1.0E-281, 1.0E-280, 1.0E-279, 1.0E-278, 1.0E-277, 1.0E-276, 1.0E-275, 1.0E-274, 
               1.0E-273, 1.0E-272, 1.0E-271, 1.0E-270, 1.0E-269, 1.0E-268, 1.0E-267, 1.0E-266, 1.0E-265, 1.0E-264, 
               1.0E-263, 1.0E-262, 1.0E-261, 1.0E-260, 1.0E-259, 1.0E-258, 1.0E-257, 1.0E-256, 1.0E-255, 1.0E-254, 
               1.0E-253, 1.0E-252, 1.0E-251, 1.0E-250, 1.0E-249, 1.0E-248, 1.0E-247, 1.0E-246, 1.0E-245, 1.0E-244, 
               1.0E-243, 1.0E-242, 1.0E-241, 1.0E-240, 1.0E-239, 1.0E-238, 1.0E-237, 1.0E-236, 1.0E-235, 1.0E-234, 
               1.0E-233, 1.0E-232, 1.0E-231, 1.0E-230, 1.0E-229, 1.0E-228, 1.0E-227, 1.0E-226, 1.0E-225, 1.0E-224, 
               1.0E-223, 1.0E-222, 1.0E-221, 1.0E-220, 1.0E-219, 1.0E-218, 1.0E-217, 1.0E-216, 1.0E-215, 1.0E-214, 
               1.0E-213, 1.0E-212, 1.0E-211, 1.0E-210, 1.0E-209, 1.0E-208, 1.0E-207, 1.0E-206, 1.0E-205, 1.0E-204, 
               1.0E-203, 1.0E-202, 1.0E-201, 1.0E-200, 1.0E-199, 1.0E-198, 1.0E-197, 1.0E-196, 1.0E-195, 1.0E-194, 
               1.0E-193, 1.0E-192, 1.0E-191, 1.0E-190, 1.0E-189, 1.0E-188, 1.0E-187, 1.0E-186, 1.0E-185, 1.0E-184, 
               1.0E-183, 1.0E-182, 1.0E-181, 1.0E-180, 1.0E-179, 1.0E-178, 1.0E-177, 1.0E-176, 1.0E-175, 1.0E-174, 
               1.0E-173, 1.0E-172, 1.0E-171, 1.0E-170, 1.0E-169, 1.0E-168, 1.0E-167, 1.0E-166, 1.0E-165, 1.0E-164, 
               1.0E-163, 1.0E-162, 1.0E-161, 1.0E-160, 1.0E-159, 1.0E-158, 1.0E-157, 1.0E-156, 1.0E-155, 1.0E-154, 
               1.0E-153, 1.0E-152, 1.0E-151, 1.0E-150, 1.0E-149, 1.0E-148, 1.0E-147, 1.0E-146, 1.0E-145, 1.0E-144, 
               1.0E-143, 1.0E-142, 1.0E-141, 1.0E-140, 1.0E-139, 1.0E-138, 1.0E-137, 1.0E-136, 1.0E-135, 1.0E-134, 
               1.0E-133, 1.0E-132, 1.0E-131, 1.0E-130, 1.0E-129, 1.0E-128, 1.0E-127, 1.0E-126, 1.0E-125, 1.0E-124, 
               1.0E-123, 1.0E-122, 1.0E-121, 1.0E-120, 1.0E-119, 1.0E-118, 1.0E-117, 1.0E-116, 1.0E-115, 1.0E-114, 
               1.0E-113, 1.0E-112, 1.0E-111, 1.0E-110, 1.0E-109, 1.0E-108, 1.0E-107, 1.0E-106, 1.0E-105, 1.0E-104, 
               1.0E-103, 1.0E-102, 1.0E-101, 1.0E-100, 1.0E-99,  1.0E-98,  1.0E-97,  1.0E-96,  1.0E-95,  1.0E-94, 
               1.0E-93,  1.0E-92,  1.0E-91,  1.0E-90,  1.0E-89,  1.0E-88,  1.0E-87,  1.0E-86,  1.0E-85,  1.0E-84, 
               1.0E-83,  1.0E-82,  1.0E-81,  1.0E-80,  1.0E-79,  1.0E-78,  1.0E-77,  1.0E-76,  1.0E-75,  1.0E-74, 
               1.0E-73,  1.0E-72,  1.0E-71,  1.0E-70,  1.0E-69,  1.0E-68,  1.0E-67,  1.0E-66,  1.0E-65,  1.0E-64, 
               1.0E-63,  1.0E-62,  1.0E-61,  1.0E-60,  1.0E-59,  1.0E-58,  1.0E-57,  1.0E-56,  1.0E-55,  1.0E-54, 
               1.0E-53,  1.0E-52,  1.0E-51,  1.0E-50,  1.0E-49,  1.0E-48,  1.0E-47,  1.0E-46,  1.0E-45,  1.0E-44, 
               1.0E-43,  1.0E-42,  1.0E-41,  1.0E-40,  1.0E-39,  1.0E-38,  1.0E-37,  1.0E-36,  1.0E-35,  1.0E-34, 
               1.0E-33,  1.0E-32,  1.0E-31,  1.0E-30,  1.0E-29,  1.0E-28,  1.0E-27,  1.0E-26,  1.0E-25,  1.0E-24, 
               1.0E-23,  1.0E-22,  1.0E-21,  1.0E-20,  1.0E-19,  1.0E-18,  1.0E-17,  1.0E-16,  1.0E-15,  1.0E-14, 
               1.0E-13,  1.0E-12,  1.0E-11,  1.0E-10,  1.0E-9,   1.0E-8,   1.0E-7,   1.0E-6,   1.0E-5,   1.0E-4, 
               1.0E-3,   1.0E-2,   1.0E-1,   1.0E0,    1.0E1,    1.0E2,    1.0E3,    1.0E4, 
               1.0E5,    1.0E6,    1.0E7,    1.0E8,    1.0E9,    1.0E10,   1.0E11,   1.0E12,   1.0E13,   1.0E14, 
               1.0E15,   1.0E16,   1.0E17,   1.0E18,   1.0E19,   1.0E20,   1.0E21,   1.0E22,   1.0E23,   1.0E24, 
               1.0E25,   1.0E26,   1.0E27,   1.0E28,   1.0E29,   1.0E30,   1.0E31,   1.0E32,   1.0E33,   1.0E34, 
               1.0E35,   1.0E36,   1.0E37,   1.0E38,   1.0E39,   1.0E40,   1.0E41,   1.0E42,   1.0E43,   1.0E44, 
               1.0E45,   1.0E46,   1.0E47,   1.0E48,   1.0E49,   1.0E50,   1.0E51,   1.0E52,   1.0E53,   1.0E54, 
               1.0E55,   1.0E56,   1.0E57,   1.0E58,   1.0E59,   1.0E60,   1.0E61,   1.0E62,   1.0E63,   1.0E64, 
               1.0E65,   1.0E66,   1.0E67,   1.0E68,   1.0E69,   1.0E70,   1.0E71,   1.0E72,   1.0E73,   1.0E74, 
               1.0E75,   1.0E76,   1.0E77,   1.0E78,   1.0E79,   1.0E80,   1.0E81,   1.0E82,   1.0E83,   1.0E84, 
               1.0E85,   1.0E86,   1.0E87,   1.0E88,   1.0E89,   1.0E90,   1.0E91,   1.0E92,   1.0E93,   1.0E94, 
               1.0E95,   1.0E96,   1.0E97,   1.0E98,   1.0E99,   1.0E100,  1.0E101,  1.0E102,  1.0E103,  1.0E104, 
               1.0E105,  1.0E106,  1.0E107,  1.0E108,  1.0E109,  1.0E110,  1.0E111,  1.0E112,  1.0E113,  1.0E114, 
               1.0E115,  1.0E116,  1.0E117,  1.0E118,  1.0E119,  1.0E120,  1.0E121,  1.0E122,  1.0E123,  1.0E124, 
               1.0E125,  1.0E126,  1.0E127,  1.0E128,  1.0E129,  1.0E130,  1.0E131,  1.0E132,  1.0E133,  1.0E134, 
               1.0E135,  1.0E136,  1.0E137,  1.0E138,  1.0E139,  1.0E140,  1.0E141,  1.0E142,  1.0E143,  1.0E144, 
               1.0E145,  1.0E146,  1.0E147,  1.0E148,  1.0E149,  1.0E150,  1.0E151,  1.0E152,  1.0E153,  1.0E154, 
               1.0E155,  1.0E156,  1.0E157,  1.0E158,  1.0E159,  1.0E160,  1.0E161,  1.0E162,  1.0E163,  1.0E164, 
               1.0E165,  1.0E166,  1.0E167,  1.0E168,  1.0E169,  1.0E170,  1.0E171,  1.0E172,  1.0E173,  1.0E174, 
               1.0E175,  1.0E176,  1.0E177,  1.0E178,  1.0E179,  1.0E180,  1.0E181,  1.0E182,  1.0E183,  1.0E184, 
               1.0E185,  1.0E186,  1.0E187,  1.0E188,  1.0E189,  1.0E190,  1.0E191,  1.0E192,  1.0E193,  1.0E194, 
               1.0E195,  1.0E196,  1.0E197,  1.0E198,  1.0E199,  1.0E200,  1.0E201,  1.0E202,  1.0E203,  1.0E204, 
               1.0E205,  1.0E206,  1.0E207,  1.0E208,  1.0E209,  1.0E210,  1.0E211,  1.0E212,  1.0E213,  1.0E214, 
               1.0E215,  1.0E216,  1.0E217,  1.0E218,  1.0E219,  1.0E220,  1.0E221,  1.0E222,  1.0E223,  1.0E224, 
               1.0E225,  1.0E226,  1.0E227,  1.0E228,  1.0E229,  1.0E230,  1.0E231,  1.0E232,  1.0E233,  1.0E234, 
               1.0E235,  1.0E236,  1.0E237,  1.0E238,  1.0E239,  1.0E240,  1.0E241,  1.0E242,  1.0E243,  1.0E244, 
               1.0E245,  1.0E246,  1.0E247,  1.0E248,  1.0E249,  1.0E250,  1.0E251,  1.0E252,  1.0E253,  1.0E254, 
               1.0E255,  1.0E256,  1.0E257,  1.0E258,  1.0E259,  1.0E260,  1.0E261,  1.0E262,  1.0E263,  1.0E264, 
               1.0E265,  1.0E266,  1.0E267,  1.0E268,  1.0E269,  1.0E270,  1.0E271,  1.0E272,  1.0E273,  1.0E274, 
               1.0E275,  1.0E276,  1.0E277,  1.0E278,  1.0E279,  1.0E280,  1.0E281,  1.0E282,  1.0E283,  1.0E284, 
               1.0E285,  1.0E286,  1.0E287,  1.0E288,  1.0E289,  1.0E290,  1.0E291,  1.0E292,  1.0E293,  1.0E294, 
               1.0E295,  1.0E296,  1.0E297,  1.0E298,  1.0E299,  1.0E300,  1.0E301,  1.0E302,  1.0E303,  1.0E304, 
               1.0E305,  1.0E306,  1.0E307,  1.0E308
            );

CONST
   expMask = 07FFFFFFFH;
   expShift = 52;
   expBias = 03FFH;

INLINE PROCEDURE BinaryExponent( R : LONGREAL ) : INTEGER;
CONST
   expShift = 52-32; // we operate directly upper DWORD
BEGIN
   RETURN PCARD32( ADR( R )@[4] )^ AND expMask >> expShift - expBias;
END BinaryExponent;
  
INLINE PROCEDURE TenExponent( R : LONGREAL ) : INTEGER;
CONST
   log2 = 0.301029995663981;
VAR
   Exp10 : INTEGER;
BEGIN
   Exp10 := INTEGER( LONGREAL( BinaryExponent( R )) * log2 );

   IF Exp10 < -323 THEN
      Exp10 := -323;
   ELSIF Exp10 > 308 THEN
      Exp10 := 308;
   END;

   IF R >= pow10[ Exp10 ] THEN
      WHILE ( Exp10 < 309 ) AND ( R >= pow10[ Exp10 ] ) DO
         INC( Exp10 );
      END;
      DEC( Exp10 );
   ELSE
      WHILE ( Exp10 > -324 ) AND ( R < pow10[ Exp10 ] ) DO
         DEC( Exp10 );
      END;
   END;
   
   RETURN Exp10;
END TenExponent;

VAR
   lr : LONGREAL;

PROCEDURE F( r : LONGREAL );
BEGIN
   lr := 1.0-r;
END F;
*)
  
   #save, call( convention => cdecl )
   PROCEDURE wmain09() : INTEGER;
   #restore
   CONST
      crlf = 13W + 10W;
      R = 123456.7788997788;
      L = 1000000;
   VAR
      i : CARDINAL;
      s : LONGREAL;
      S : ARRAY [0..255] OF WCHAR;
      t : Time.TTime64;
   BEGIN

(*   
      t := Time.time();
      FOR i := 0 TO L-1 DO
         Str.CorrectedRealToStrW( R, 15, FALSE, S, b );
      END;
      s := Time.difftime( Time.time(), t );
      
      windows.OutputDebugStringW( L"mii: " );
      windows.OutputDebugStringW( ADR( S ));
      Strings.FromLONGREALW( s, -1, -1, OUT S );
      windows.OutputDebugStringW( L", time: " );
      windows.OutputDebugStringW( ADR( S ));
      windows.OutputDebugStringW( ADR( crlf ));
*)      

      t := Time.time();
      FOR i := 0 TO L-1 DO
         Strings.FromLONGREALExtW( R, -1, -1, FALSE, L"", OUT S );
      END;
      s := Time.difftime( Time.time(), t );

      windows.OutputDebugStringW( L"cpp: " );
      windows.OutputDebugStringW( ADR( S ));
      Strings.FromLONGREALExtW( s, -1, -1, FALSE, L"", OUT S );
      windows.OutputDebugStringW( L", time: " );
      windows.OutputDebugStringW( ADR( S ));
      windows.OutputDebugStringW( ADR( crlf ));

      t := Time.time();
      FOR i := 0 TO L-1 DO
         lrconv.LONGREALToStrW( R, -1, -1, FALSE, 0W, OUT S );
      END;
      s := Time.difftime( Time.time(), t );

      windows.OutputDebugStringW( L"lrc: " );
      windows.OutputDebugStringW( ADR( S ));
      Strings.FromLONGREALExtW( s, -1, -1, FALSE, 0W, OUT S );
      windows.OutputDebugStringW( L", time: " );
      windows.OutputDebugStringW( ADR( S ));
      windows.OutputDebugStringW( ADR( crlf ));

(*
      t := Time.time();
      FOR i := 0 TO 10000*L-1 DO
         F( math.log10( 5.467777 ));
      END;
      s := Time.difftime( Time.time(), t );

      Strings.FromLONGREALW( s, -1, -1, OUT S );
      windows.OutputDebugStringW( L"cma: " );
      windows.OutputDebugStringW( ADR( S ));
      windows.OutputDebugStringW( ADR( crlf ));

      t := Time.time();
      FOR i := 0 TO 10000*L-1 DO
         F( LONGREAL( TenExponent( 5.467777 )));
      END;
      s := Time.difftime( Time.time(), t );

      Strings.FromLONGREALW( s, -1, -1, OUT S );
      windows.OutputDebugStringW( L"lma: " );
      windows.OutputDebugStringW( ADR( S ));
      windows.OutputDebugStringW( ADR( crlf ));
*)

      RETURN 0;
   END wmain09;

END lrconvspeed.