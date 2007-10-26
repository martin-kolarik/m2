MODULE inheritedinterfaces;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

INTERFACE A;
   PROCEDURE MA();
END A;

INTERFACE B( A );
   PROCEDURE MB();
END B;

CLASS X IMPLEMENTS A;
   PUBLIC VIRTUAL PROCEDURE MA();
END X;

CLASS Y( X ) IMPLEMENTS B;
   PUBLIC VIRTUAL PROCEDURE MA();
   PUBLIC VIRTUAL PROCEDURE MB();
END Y;

VAR
   G : CARDINAL := 0;

CLASS IMPLEMENTATION X;

   PUBLIC VIRTUAL PROCEDURE MA();
   BEGIN
      INC( G, 1 );
   END MA;

END X;

CLASS IMPLEMENTATION Y;

   PUBLIC VIRTUAL PROCEDURE MA();
   BEGIN
      INC( G, 1 );
   END MA;

   PUBLIC VIRTUAL PROCEDURE MB();
   BEGIN
      INC( G, 2 );
   END MB;

END Y;

TYPE
   TPA = POINTER TO A;
   TPB = POINTER TO B;
   TPX = POINTER TO X;
   TPY = POINTER TO Y;

#save, call( convention => cdecl )
PROCEDURE wmain();
VAR
   VX : X;
   VY : Y;
BEGIN
   VX.MA();
   VY.MA();
   VY.MB();
END wmain;
#restore

END inheritedinterfaces.