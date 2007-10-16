MODULE infiniteloop;

  PROCEDURE ILoop1();
  BEGIN
    LOOP
    END;
  END ILoop1;

  PROCEDURE NLoop1();
  BEGIN
    LOOP
      EXIT;
    END;
  END NLoop1;

  PROCEDURE NLoop2();
  BEGIN
    LOOP
      IF FALSE THEN
        RETURN;
      END;  
    END;
  END NLoop2;

BEGIN
END infiniteloop.