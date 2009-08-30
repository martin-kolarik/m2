/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.business.implementation.number;

import cz.smartcontrol.licensing.business.implementation.support.Key;
import cz.smartcontrol.licensing.business.implementation.support.CRCCCITT;
import cz.smartcontrol.licensing.business.implementation.support.Hash40;
import java.util.Calendar;
import java.util.Date;
import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;

/**
 *
 * @author Martin
 */
public class Activation extends Number {
    
    private static String ACTIVATION_PREFIX = "VAN";
    private static char ACTIVATION_SEPARATOR = '-';
    private static int ACTIVATION_DATA_LENGTH = 2 * 5 + 2 + 1 + 3;
    private static int ACTIVATION_PACKET_LENGTH = 2 + ACTIVATION_DATA_LENGTH; // permute, pid, mid, to, delay, gord
        
    private static byte[] cai = {
        0x025, 0x001, (byte)0x090, 0x019, (byte)0x0CF, (byte)0x0FB, (byte)0x0D9, (byte)0x099, 0x01C, (byte)0x0B7, 0x068, 0x025, 0x074, (byte)0x08D, (byte)0x094, 0x05F,
        0x030, (byte)0x093, (byte)0x095, 0x042, 0x077, 0x00D, 0x019, (byte)0x0B1, 0x021, (byte)0x0FD, 0x000, 0x042, (byte)0x09C, 0x03E, 0x00C, (byte)0x0A5
    };
    private static byte[] cak = {
        (byte)0x085, 0x037, 0x01C, (byte)0x0A6, (byte)0x0E5, 0x050, 0x014, 0x03D, (byte)0x0CE, 0x028, 0x003, 0x047, 0x01B, (byte)0x0DE, 0x03A, 0x009,
        (byte)0x0E8, (byte)0x0F8, 0x077, 0x00F, (byte)0x0A2, 0x033, (byte)0x09B, 0x04C, 0x074, 0x078, 0x073, (byte)0x0D4, 0x06C, (byte)0x0E7, (byte)0x0C1, (byte)0x0F3
    };
    
    private Hash40 _MId = new Hash40();
    private Hash40 _PId = new Hash40();
    private int _Origin = -1;
    private int _Months = -1;
    private int _GOrd;
    
    public char getSeparator()
    {
        return ACTIVATION_SEPARATOR;
    }

    public String getPrefix()
    {
        return ACTIVATION_PREFIX;
    }
    
    public Hash40 getMId()
    {
        return _MId;
    }
    
    public void setMId( Hash40 value )
    {
        _MId = value;
    }
    
    public Hash40 getPId()
    {
        return _PId;
    }
    
    public void setPId( Hash40 value )
    {
        _PId = value;
    }
    
    public Date getOrigin() {
        // TODO
        return Calendar.getInstance().getTime();
    }

    public void setOrigin( int Date ) {
    }

    public int getMonths() {
        return _Months;
    }

    public void setMonths( int Months ) {
        this._Months = Months;
    }

    public int getGOrd() {
        return _GOrd;
    }

    public void setGOrd( int GOrd ) {
        this._GOrd = GOrd;
    }

    public void setOA( byte[] oa )
    {
        if( oa.length != ACTIVATION_PACKET_LENGTH )
        {
            return;
        }
        
        Key key = new Key( cak );
        Key iv = new Key( cai );
        int permuteShift = oa[0] << 8 | oa[1];
        permute( permuteShift, key, iv );

        byte[] packet = new byte[ACTIVATION_DATA_LENGTH];
        System.arraycopy( oa, 2, packet, 0, ACTIVATION_DATA_LENGTH );
        
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

        _Origin = packet[10] | packet[11] << 8;
        if( _Origin == 0xffff )
        {
            _Origin = -1;
        }

        _Months = packet[12];
        if( _Months == 0xff )
        {
            _Months = -1;
        }
        
        _GOrd = packet[13] << 16 | packet[14] << 8 | packet[15];
    }
    
    public byte[] getOA()
    {
        byte[] packet = new byte[ACTIVATION_DATA_LENGTH];

        // create packet
        System.arraycopy( _PId.get(), 0, packet, 0, _PId.length() );
        System.arraycopy( _MId.get(), 0, packet, 5, _MId.length() );

        packet[10] = (byte)_Origin;
        packet[11] = (byte)(_Origin >> 8);
        packet[12] = (byte)_Months;
        packet[13] = (byte)(_GOrd >> 16);
        packet[14] = (byte)(_GOrd >> 8);
        packet[15] = (byte)(_GOrd >> 0);

        byte[] digest = digestSalt( packet, salt );

        Key key = new Key( cak );
        Key iv = new Key( cai );
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

        byte[] oa = new byte[ACTIVATION_PACKET_LENGTH];
        oa[0] = (byte)(permuteShift >> 8);
        oa[1] = (byte)(permuteShift & 0xff);
        System.arraycopy( packet, 0, oa, 2, packet.length );

        return oa;
    }

}
