/* memory functions */
/* functions prefixed with "x" are not used, as they are linked from ntdll.lib */

/* Set C bytes at address D to the (8 bit) value V
 */
void* __cdecl xmemset( void *d, int v, unsigned long c )
{
typedef unsigned char BYTE;
typedef BYTE* ADDRESS;
typedef unsigned int UINT;

    if ((((UINT)d) | c) & (sizeof(int) - 1))
    {
        BYTE *pD = (BYTE *) d;
        BYTE *pE = (BYTE *) (((ADDRESS) d) + c);

        while (pD != pE)
        {
            *(pD++) = (BYTE) v;
        }
    }
    else
    {
        UINT *pD = (UINT *) d;
        UINT *pE = (UINT *) (BYTE *) (((ADDRESS) d) + c);
        UINT uv;

        uv = ((UINT) (v & 0xff)) | (((UINT) (v & 0xff)) << 8);
        uv |= uv << 16; /* Our processors are at least 32 bits */

#ifdef _W64
        uv |= uv << 32;
#endif

        while (pD != pE)
        {
            *(pD++) = uv;
        }
    }
    return d;
}
