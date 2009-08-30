/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.business.implementation.number;

import cz.smartcontrol.licensing.business.implementation.support.Key;
import cz.smartcontrol.licensing.business.implementation.support.CRCCCITT;
import cz.smartcontrol.licensing.business.implementation.support.Hash40;
import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;

/**
 *
 * @author Martin
 */
public class Registration extends Number {
    
    private static String REGISTRATION_PREFIX = "REG";
    private static char REGISTRATION_SEPARATOR = '-';
    private static int REGISTRATION_DATA_LENGTH = 2 * 5 + 2 + 1 + 3;
    private static int REGISTRATION_PACKET_LENGTH = 2 + REGISTRATION_DATA_LENGTH; // permute, pid, mid, to, delay, gord
        
    private static byte[] cri = {
        (byte)0x0EB, 0x04B, 0x047, (byte)0x0A1, (byte)0x080, (byte)0x0BB, (byte)0x084, (byte)0x0FA, 0x07D, (byte)0x0A3, (byte)0x0ED, 0x011, (byte)0x0FC, 0x01D, (byte)0x0E1, 0x069,
        0x000, (byte)0x0E4, 0x052, (byte)0x08E, 0x059, 0x044, (byte)0x08B, 0x057, (byte)0x08F, 0x01D, 0x072, (byte)0x0C5, (byte)0x0B4, (byte)0x0D3, (byte)0x0BE, 0x000
    };
    private static byte[] crk = {
        (byte)0x0D9, (byte)0x0BF, (byte)0x079, 0x02A, (byte)0x0A3, (byte)0x097, (byte)0x0A5, (byte)0x0B8, 0x02F, 0x00A, 0x037, 0x052, 0x071, (byte)0x0F1, (byte)0x09B, (byte)0x0AA,
        (byte)0x087, 0x06B, 0x018, (byte)0x0BF, (byte)0x097, (byte)0x097, 0x01A, (byte)0x088, (byte)0x091, 0x007, 0x06F, 0x02E, 0x00B, (byte)0x094, (byte)0x08C, 0x07D
    };
    
    private Hash40 _MId = new Hash40();
    private Hash40 _PId = new Hash40();
    private byte[] _OSVer = new byte[3];
    private int _GOrd;

    public char getSeparator()
    {
        return REGISTRATION_SEPARATOR;
    }

    public String getPrefix()
    {
        return REGISTRATION_PREFIX;
    }
    
    public Hash40 getMId() {
        return _MId;
    }

    public void setMId( Hash40 MId ) {
        this._MId = MId;
    }

    public Hash40 getPId() {
        return _PId;
    }

    public void setPId( Hash40 PId ) {
        this._PId = PId;
    }

    public int getGOrd() {
        return _GOrd;
    }

    public void setGOrd( int GOrd ) {
        this._GOrd = GOrd;
    }

    public void setOA( byte[] oa )
    {
        if( oa.length != REGISTRATION_PACKET_LENGTH )
        {
            return;
        }
        
        Key key = new Key( crk  );
        Key iv = new Key( cri  );
        int permuteShift = oa[0] << 8 | oa[1];
        permute( permuteShift, key, iv );

        byte[] packet = new byte[REGISTRATION_DATA_LENGTH];
        System.arraycopy( oa, 2, packet, 0, REGISTRATION_DATA_LENGTH  );
        
        try
        {
            Cipher cipher = Cipher.getInstance( "AES/OFB" );
            SecretKeySpec keySpec = new SecretKeySpec( key.get(), "AES" );
            cipher.init( Cipher.ENCRYPT_MODE, keySpec, new IvParameterSpec( iv.get() ));
            packet = cipher.doFinal( packet );
            
            byte[] digest = digestSalt( packet, salt );
            if( permuteShift != CRCCCITT.crc( digest ))
            {
                return;
            }
        }
        catch( Exception e )
        {}

        System.arraycopy( packet, 0, _PId.get(), 0, _PId.length() );
        System.arraycopy( packet, 5, _MId.get(), 0, _MId.length() );

        _OSVer[0] = packet[10];
        _OSVer[1] = packet[11];
        _OSVer[2] = packet[12];

        _GOrd = packet[13] << 16 | packet[14] << 8 | packet[15];
    }
    
    public byte[] getOA()
    {
        byte[] packet = new byte[REGISTRATION_DATA_LENGTH];

        // create packet
        System.arraycopy( _PId.get(), 0, packet, 0, _PId.length() );
        System.arraycopy( _MId.get(), 0, packet, 5, _MId.length() );

        packet[10] = _OSVer[0];
        packet[11] = _OSVer[1];
        packet[12] = _OSVer[2];
        packet[13] = (byte)(_GOrd >> 16);
        packet[14] = (byte)(_GOrd >> 8);
        packet[15] = (byte)(_GOrd >> 0);

        byte[] digest = digestSalt( packet, salt );

        Key key = new Key( crk  );
        Key iv = new Key( cri  );
        int permuteShift = CRCCCITT.crc( digest );
        permute( permuteShift, key, iv );

        try
        {
            Cipher cipher = Cipher.getInstance( "AES/OFB" );
            SecretKeySpec keySpec = new SecretKeySpec( key.get(), "AES" );
            cipher.init( Cipher.DECRYPT_MODE, keySpec, new IvParameterSpec( iv.get() ));
            packet = cipher.doFinal( packet );
        }
        catch( Exception e )
        {}

        byte[] oa = new byte[REGISTRATION_PACKET_LENGTH];
        oa[0] = (byte)(permuteShift >> 8);
        oa[1] = (byte)(permuteShift & 0xff);
        System.arraycopy( packet, 0, oa, 2, packet.length );

        return oa;
    }

}
