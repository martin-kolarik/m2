IMPLEMENTATION MODULE testfactory;

IMPORT
   testimpl;
   
PROCEDURE Factory( CONST ClassPath : ARRAY OF WCHAR; OUT Object : ADDRESS ) : CARDINAL;
BEGIN
   RETURN testimpl.tests()^.TestFactory( ClassPath, OUT Object );
END Factory;

END testfactory.