/* stack allocation probes */
/* functions prefixed with "x" are not used, as they are linked from ntdll.lib */

__declspec(naked) void* __cdecl x_chkstk()
{
    __asm
    {
	    /* save edx to restore before returning */
		push    edx

    	/* start edx just before return address and stored edx */
    	lea		edx, [esp+8]
    		
    	/* Now, allocate the space in 4K chunks, probing each time, to make */
    	/* sure the system allocates each of the new pages needed */
    		
next_four_k:
    	cmp		eax, 0x1000			/* less than 0x1000 to go? */
    	jb		last_one			/* if so, see the last one */
    	sub		edx, 0x1000			/* if not, add a page */
    	or		dword ptr[edx], 0	/* touch the memory */
    	sub		eax, 0x1000			/* decrement memory count */
    	jmp		next_four_k			/* and do it again */
    		
last_one:
    	sub		edx, eax			/* now, just finish off the allocation */
    	mov		eax, esp			/* save sp to we can restore context */
    	mov		esp, edx			/* store new SP into the real SP */
    	mov		edx, [eax]			/* restore edx */
    	or		dword ptr[esp], 0	/* touch the memory */
		push	[eax+4]				/* setup return addr */
		lea		eax, [esp+4]		/* store new ESP into eax for return value */
    	ret							/* and return to the caller */
    }
}
