IMPLEMENTATION MODULE stack;
// ADT Stack

CLASS IMPLEMENTATION CStack;

  PROCEDURE CStack.Push( Object : list.TPListElem );
  BEGIN
    InsertFirst( Object );
  END CStack.Push;
  
  PROCEDURE CStack.Peek( OUT Object : list.TPListElem ) : BOOLEAN; 
  BEGIN
    RETURN GetFirst( OUT Object );
  END CStack.Peek;

  PROCEDURE CStack.Pop( OUT Object : list.TPListElem ) : BOOLEAN; 
  BEGIN
    IF NOT GetFirst( OUT Object ) THEN
      RETURN FALSE;
    END;
    Remove( Object );
    RETURN TRUE;
  END CStack.Pop;

END CStack;

END stack.
